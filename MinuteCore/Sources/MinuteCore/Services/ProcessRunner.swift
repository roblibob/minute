import Foundation

public struct ProcessResult: Sendable, Equatable {
    public var exitCode: Int32
    public var stdout: String
    public var stderr: String

    public var combinedOutput: String {
        switch (stdout.isEmpty, stderr.isEmpty) {
        case (true, true):
            return ""
        case (false, true):
            return stdout
        case (true, false):
            return stderr
        case (false, false):
            return stdout + "\n" + stderr
        }
    }

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public enum ProcessRunnerError: Error, Sendable, Equatable {
    case failedToLaunch(underlyingDescription: String)
    case outputLimitExceeded(maximumBytes: Int)
}

public protocol ProcessRunning: Sendable {
    /// Runs a subprocess and captures stdout/stderr.
    ///
    /// - Note: This method supports cancellation. On cancel it terminates the subprocess.
    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        workingDirectoryURL: URL?,
        maximumOutputBytes: Int
    ) async throws -> ProcessResult
}

/// Default Process runner used for invoking bundled executables (whisper/llama/ffmpeg).
///
/// Design goals:
/// - Read stdout/stderr concurrently to avoid pipe deadlocks.
/// - Support cancellation by terminating the running process.
/// - Impose an upper bound on captured output to avoid runaway memory use.
public struct DefaultProcessRunner: ProcessRunning {
    public init() {}

    public func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]? = nil,
        workingDirectoryURL: URL? = nil,
        maximumOutputBytes: Int = 5 * 1024 * 1024
    ) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = workingDirectoryURL

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading

        return try await withTaskCancellationHandler {
            do {
                try process.run()
            } catch {
                throw ProcessRunnerError.failedToLaunch(underlyingDescription: String(describing: error))
            }

            async let terminationStatus: Int32 = waitForTermination(process)
            async let stdoutData: Data = readAllData(from: stdoutHandle, maximumBytes: maximumOutputBytes)
            async let stderrData: Data = readAllData(from: stderrHandle, maximumBytes: maximumOutputBytes)

            let (exitCode, outData, errData) = try await (terminationStatus, stdoutData, stderrData)

            // Close handles; best-effort.
            try? stdoutHandle.close()
            try? stderrHandle.close()

            let stdout = String(decoding: outData, as: UTF8.self)
            let stderr = String(decoding: errData, as: UTF8.self)

            return ProcessResult(exitCode: exitCode, stdout: stdout, stderr: stderr)
        } onCancel: {
            // Best-effort cancellation: terminate the process, then close pipes so readers unblock.
            if process.isRunning {
                process.terminate()
            }
            try? stdoutHandle.close()
            try? stderrHandle.close()
        }
    }

    private func waitForTermination(_ process: Process) async -> Int32 {
        await withCheckedContinuation { continuation in
            process.terminationHandler = { proc in
                continuation.resume(returning: proc.terminationStatus)
            }
        }
    }

    private func readAllData(from handle: FileHandle, maximumBytes: Int) async throws -> Data {
        var buffer = Data()

        while true {
            let chunk = try handle.read(upToCount: 16 * 1024)
            guard let chunk, !chunk.isEmpty else {
                break
            }

            buffer.append(chunk)
            if buffer.count > maximumBytes {
                throw ProcessRunnerError.outputLimitExceeded(maximumBytes: maximumBytes)
            }
        }

        return buffer
    }
}
