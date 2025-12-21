import Foundation
import os

public struct WhisperTranscriptionConfiguration: Sendable, Equatable {
    /// Whisper CLI executable location (bundled in the app or provided via env var for development).
    public var executableURL: URL

    /// Whisper model file location (downloaded under Application Support; task 09).
    public var modelURL: URL

    /// Fixed language to reduce variability.
    public var language: String

    /// Optional fixed thread count.
    public var threads: Int?

    public init(executableURL: URL, modelURL: URL, language: String = "en", threads: Int? = nil) {
        self.executableURL = executableURL
        self.modelURL = modelURL
        self.language = language
        self.threads = threads
    }
}

public struct WhisperTranscriptionService: TranscriptionServicing {
    private let configuration: WhisperTranscriptionConfiguration
    private let processRunner: any ProcessRunning
    private let maximumOutputBytes: Int
    private let logger = Logger(subsystem: "roblibob.Minute", category: "whisper")

    public init(
        configuration: WhisperTranscriptionConfiguration,
        processRunner: some ProcessRunning = DefaultProcessRunner(),
        maximumOutputBytes: Int = 5 * 1024 * 1024
    ) {
        self.configuration = configuration
        self.processRunner = processRunner
        self.maximumOutputBytes = maximumOutputBytes
    }

    /// Creates a service using the default model location and an executable resolved from either:
    /// 1) `$MINUTE_WHISPER_BIN` (absolute path), or
    /// 2) a bundled executable named `whisper`.
    public static func liveDefault() throws -> WhisperTranscriptionService {
        guard let executableURL = WhisperExecutableLocator.resolveExecutableURL() else {
            throw MinuteError.whisperMissing
        }

        // Default to the multilingual base model so we can transcribe both Swedish + English.
        let modelURL = WhisperModelPaths.defaultBaseModelURL

        return WhisperTranscriptionService(
            configuration: WhisperTranscriptionConfiguration(executableURL: executableURL, modelURL: modelURL, language: "auto")
        )
    }

    public func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        // Validate executable.
        guard FileManager.default.isExecutableFile(atPath: configuration.executableURL.path) else {
            throw MinuteError.whisperMissing
        }

        // Validate model.
        guard FileManager.default.fileExists(atPath: configuration.modelURL.path) else {
            throw MinuteError.modelMissing
        }

        let outputBaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-whisper-\(UUID().uuidString)")
        let outputJSONURL = outputBaseURL.appendingPathExtension("json")

        defer {
            try? FileManager.default.removeItem(at: outputJSONURL)
        }

        // Deterministic whisper.cpp CLI invocation.
        //
        // - `-m`: model path
        // - `-f`: WAV input
        // - `-l`: fixed language
        // - `-oj`: output JSON
        // - `-of`: output base path
        // - `-np`: no progress output
        // - `-t`: fixed thread count (optional)
        var args: [String] = [
            "-m", configuration.modelURL.path,
            "-f", wavURL.path,
            "-l", configuration.language,
            "-oj",
            "-of", outputBaseURL.path,
            "-np",
        ]

        if let threads = configuration.threads {
            args.append(contentsOf: ["-t", String(threads)])
        }

        do {
            logger.info("Running whisper: executable=\(self.configuration.executableURL.path, privacy: .public) model=\(self.configuration.modelURL.lastPathComponent, privacy: .public)")

            let result = try await processRunner.run(
                executableURL: configuration.executableURL,
                arguments: args,
                environment: nil,
                workingDirectoryURL: nil,
                maximumOutputBytes: maximumOutputBytes
            )

            if result.exitCode != 0 {
                // Include stdout/stderr for debug UI, but never write this to the vault.
                throw MinuteError.whisperFailed(exitCode: result.exitCode, output: result.combinedOutput)
            }

            if let jsonData = try? Data(contentsOf: outputJSONURL),
               let output = WhisperCLIJSONDecoder.decode(data: jsonData),
               !output.text.isEmpty {
                return TranscriptionResult(text: output.text, segments: output.segments)
            }

            // Prefer stdout, but fall back to combined output for builds that emit transcript elsewhere.
            let rawOutput = result.stdout.isEmpty ? result.combinedOutput : result.stdout
            let transcript = TranscriptNormalizer.normalizeWhisperOutput(rawOutput)

            // If we somehow got a successful exit code but no transcript, surface actionable debug.
            if transcript.isEmpty {
                throw MinuteError.whisperFailed(exitCode: result.exitCode, output: result.combinedOutput)
            }

            return TranscriptionResult(text: transcript, segments: [])
        } catch is CancellationError {
            logger.info("Whisper cancelled")
            throw CancellationError()
        } catch let error as ProcessRunnerError {
            switch error {
            case .failedToLaunch:
                throw MinuteError.whisperMissing
            case .outputLimitExceeded:
                throw MinuteError.whisperFailed(exitCode: -1, output: "whisper output exceeded limit")
            }
        }
    }
}

public enum WhisperExecutableLocator {
    /// Returns a usable whisper CLI executable URL if available.
    public static func resolveExecutableURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL? {
        if let env = environment["MINUTE_WHISPER_BIN"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }

        // Bundled executable name (task 10 will ensure it is codesigned).
        if let bundled = Bundle.main.url(forResource: "whisper", withExtension: nil),
           FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }

        if let executableFolder = Bundle.main.executableURL?.deletingLastPathComponent() {
            let bundledExecutable = executableFolder.appendingPathComponent("whisper")
            if FileManager.default.isExecutableFile(atPath: bundledExecutable.path) {
                return bundledExecutable
            }
        }

        return nil
    }
}

public enum WhisperModelPaths {
    private static var applicationSupportRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
    }

    /// Default multilingual model location.
    ///
    /// Stored under `models/whisper/` so both the CLI and library implementations can share it.
    public static var defaultBaseModelURL: URL {
        // ~/Library/Application Support/Minute/models/whisper/ggml-base.bin
        applicationSupportRoot
            .appendingPathComponent("Minute", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("whisper", isDirectory: true)
            .appendingPathComponent("ggml-base.bin")
    }

    /// Optional Core ML encoder (if the bundled whisper build expects it).
    public static var defaultBaseEncoderCoreMLURL: URL {
        // ~/Library/Application Support/Minute/models/whisper/ggml-base-encoder.mlmodelc
        applicationSupportRoot
            .appendingPathComponent("Minute", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("whisper", isDirectory: true)
            .appendingPathComponent("ggml-base-encoder.mlmodelc")
    }

    /// Default English-only model location per docs/tasks/09-model-management-downloads-and-storage.md.
    public static var defaultBaseEnModelURL: URL {
        // ~/Library/Application Support/Minute/models/whisper/base.en.bin
        applicationSupportRoot
            .appendingPathComponent("Minute", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("whisper", isDirectory: true)
            .appendingPathComponent("base.en.bin")
    }
}
