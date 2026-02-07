import Foundation
import Testing
@testable import MinuteCore

struct WhisperTranscriptionServiceTests {
    private struct MockProcessRunner: ProcessRunning {
        var handler: @Sendable (URL, [String]) async throws -> ProcessResult

        func run(
            executableURL: URL,
            arguments: [String],
            environment: [String: String]?,
            workingDirectoryURL: URL?,
            maximumOutputBytes: Int
        ) async throws -> ProcessResult {
            try await handler(executableURL, arguments)
        }
    }

    @Test
    func transcribe_whenExitCodeZero_returnsNormalizedTranscript() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let exe = tmp.appendingPathComponent("whisper")
        FileManager.default.createFile(atPath: exe.path, contents: Data())
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: exe.path)

        let model = tmp.appendingPathComponent("base.en.bin")
        FileManager.default.createFile(atPath: model.path, contents: Data([0x00]))

        let wav = tmp.appendingPathComponent("in.wav")
        FileManager.default.createFile(atPath: wav.path, contents: Data([0x00]))

        let runner = MockProcessRunner { _, _ in
            ProcessResult(
                exitCode: 0,
                stdout: "[ 12%]\nHello world.\n\n\nThis is a test.\n",
                stderr: ""
            )
        }

        let service = WhisperTranscriptionService(
            configuration: WhisperTranscriptionConfiguration(executableURL: exe, modelURL: model),
            processRunner: runner
        )

        let result = try await service.transcribe(wavURL: wav)
        expectEqual(result.text, "Hello world.\n\nThis is a test.")
    }

    @Test
    func transcribe_whenNonZeroExitCode_throwsWhisperFailedIncludingOutput() async {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let exe = tmp.appendingPathComponent("whisper")
        FileManager.default.createFile(atPath: exe.path, contents: Data())
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: exe.path)

        let model = tmp.appendingPathComponent("base.en.bin")
        FileManager.default.createFile(atPath: model.path, contents: Data([0x00]))

        let wav = tmp.appendingPathComponent("in.wav")
        FileManager.default.createFile(atPath: wav.path, contents: Data([0x00]))

        let runner = MockProcessRunner { _, _ in
            ProcessResult(exitCode: 2, stdout: "", stderr: "boom")
        }

        let service = WhisperTranscriptionService(
            configuration: WhisperTranscriptionConfiguration(executableURL: exe, modelURL: model),
            processRunner: runner
        )

        do {
            _ = try await service.transcribe(wavURL: wav)
            #expect(Bool(false))
        } catch let error as MinuteError {
            switch error {
            case .whisperFailed(let exitCode, let output):
                expectEqual(exitCode, 2)
                #expect(output.contains("boom"))
            default:
                #expect(Bool(false))
            }
        } catch {
            #expect(Bool(false))
        }
    }

    @Test
    func transcribe_whenExecutableMissing_throwsWhisperMissing() async {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let exe = tmp.appendingPathComponent("whisper")
        // Note: do not create the file.

        let model = tmp.appendingPathComponent("base.en.bin")
        FileManager.default.createFile(atPath: model.path, contents: Data([0x00]))

        let wav = tmp.appendingPathComponent("in.wav")
        FileManager.default.createFile(atPath: wav.path, contents: Data([0x00]))

        let runner = MockProcessRunner { _, _ in
            #expect(Bool(false))
            return ProcessResult(exitCode: 0, stdout: "", stderr: "")
        }

        let service = WhisperTranscriptionService(
            configuration: WhisperTranscriptionConfiguration(executableURL: exe, modelURL: model),
            processRunner: runner
        )

        do {
            _ = try await service.transcribe(wavURL: wav)
            #expect(Bool(false))
        } catch let error as MinuteError {
            guard case .whisperMissing = error else {
                #expect(Bool(false))
                return
            }
        } catch {
            #expect(Bool(false))
        }
    }

    @Test
    func transcribe_whenModelMissing_throwsModelMissing() async {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let exe = tmp.appendingPathComponent("whisper")
        FileManager.default.createFile(atPath: exe.path, contents: Data())
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: exe.path)

        let model = tmp.appendingPathComponent("base.en.bin")
        // Note: do not create the file.

        let wav = tmp.appendingPathComponent("in.wav")
        FileManager.default.createFile(atPath: wav.path, contents: Data([0x00]))

        let runner = MockProcessRunner { _, _ in
            #expect(Bool(false))
            return ProcessResult(exitCode: 0, stdout: "", stderr: "")
        }

        let service = WhisperTranscriptionService(
            configuration: WhisperTranscriptionConfiguration(executableURL: exe, modelURL: model),
            processRunner: runner
        )

        do {
            _ = try await service.transcribe(wavURL: wav)
            #expect(Bool(false))
        } catch let error as MinuteError {
            guard case .modelMissing = error else {
                #expect(Bool(false))
                return
            }
        } catch {
            #expect(Bool(false))
        }
    }
}
