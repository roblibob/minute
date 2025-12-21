import Foundation
import os

public struct LlamaSummarizationConfiguration: Sendable, Equatable {
    /// Llama CLI executable location (bundled in the app or provided via env var for development).
    public var executableURL: URL

    /// GGUF model file location (downloaded under Application Support; task 09).
    public var modelURL: URL

    /// Low temperature for determinism.
    public var temperature: Double

    public var topP: Double?

    /// Fixed seed if supported by the chosen llama.cpp CLI build.
    public var seed: Int?

    /// Maximum number of tokens to predict.
    public var maxTokens: Int

    /// Context window size.
    public var contextSize: Int?

    /// Optional fixed thread count.
    public var threads: Int?

    public init(
        executableURL: URL,
        modelURL: URL,
        temperature: Double = 0.2,
        topP: Double? = 0.9,
        seed: Int? = 42,
        maxTokens: Int = 1024,
        contextSize: Int? = 4096,
        threads: Int? = nil
    ) {
        self.executableURL = executableURL
        self.modelURL = modelURL
        self.temperature = temperature
        self.topP = topP
        self.seed = seed
        self.maxTokens = maxTokens
        self.contextSize = contextSize
        self.threads = threads
    }
}

/// Summarization + schema extraction using a local `llama.cpp` CLI executable.
///
/// Output contract: returns raw JSON string produced by the model. The JSON is *not* decoded here;
/// decoding/validation is handled by the pipeline.
public struct LlamaSummarizationService: SummarizationServicing {
    private let configuration: LlamaSummarizationConfiguration
    private let processRunner: any ProcessRunning
    private let maximumOutputBytes: Int
    private let logger = Logger(subsystem: "knowitflx.Minute", category: "llama")

    public init(
        configuration: LlamaSummarizationConfiguration,
        processRunner: some ProcessRunning = DefaultProcessRunner(),
        maximumOutputBytes: Int = 5 * 1024 * 1024
    ) {
        self.configuration = configuration
        self.processRunner = processRunner
        self.maximumOutputBytes = maximumOutputBytes
    }

    /// Creates a service using the default model location and an executable resolved from either:
    /// 1) `$MINUTE_LLAMA_BIN` (absolute path), or
    /// 2) a bundled executable named `llama`.
    public static func liveDefault(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> LlamaSummarizationService {
        guard let executableURL = LlamaExecutableLocator.resolveExecutableURL(environment: environment) else {
            throw MinuteError.llamaMissing
        }

        let modelURL = LlamaModelPaths.defaultLLMModelURL

        return LlamaSummarizationService(
            configuration: LlamaSummarizationConfiguration(executableURL: executableURL, modelURL: modelURL)
        )
    }

    public func summarize(transcript: String, meetingDate: Date) async throws -> String {
        try await runLlama(prompt: PromptBuilder.summarizationPrompt(transcript: transcript, meetingDate: meetingDate))
    }

    public func repairJSON(_ invalidJSON: String) async throws -> String {
        try await runLlama(prompt: PromptBuilder.repairPrompt(invalidOutput: invalidJSON))
    }

    // MARK: - Internals

    private func runLlama(prompt: String) async throws -> String {
        // Validate executable.
        guard FileManager.default.isExecutableFile(atPath: configuration.executableURL.path) else {
            throw MinuteError.llamaMissing
        }

        // Validate model.
        guard FileManager.default.fileExists(atPath: configuration.modelURL.path) else {
            throw MinuteError.modelMissing
        }

        // Deterministic llama.cpp CLI invocation.
        //
        // Args below target `llama-cli`-style flags. If you bundle a different build, keep this
        // mapping updated and document it in `docs/tasks/06-summarization-llama-integration.md`.
        var args: [String] = [
            "-m", configuration.modelURL.path,
            "-p", prompt,
            "--temp", String(configuration.temperature),
            "--n-predict", String(configuration.maxTokens),
        ]

        if let topP = configuration.topP {
            args.append(contentsOf: ["--top-p", String(topP)])
        }

        if let seed = configuration.seed {
            args.append(contentsOf: ["--seed", String(seed)])
        }

        if let contextSize = configuration.contextSize {
            args.append(contentsOf: ["--ctx-size", String(contextSize)])
        }

        if let threads = configuration.threads {
            args.append(contentsOf: ["--threads", String(threads)])
        }

        // Reduce variance/noise where supported.
        args.append(contentsOf: [
            "--no-display-prompt",
        ])

        do {
            logger.info("Running llama: executable=\(self.configuration.executableURL.path, privacy: .public) model=\(self.configuration.modelURL.lastPathComponent, privacy: .public)")

            let result = try await processRunner.run(
                executableURL: configuration.executableURL,
                arguments: args,
                environment: nil,
                workingDirectoryURL: nil,
                maximumOutputBytes: maximumOutputBytes
            )

            let rawOutput = result.stdout.isEmpty ? result.combinedOutput : result.stdout

            if result.exitCode != 0 {
                throw MinuteError.llamaFailed(exitCode: result.exitCode, output: result.combinedOutput)
            }

            // Best-effort: extract a JSON object if present.
            let trimmed = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            if let extracted = JSONFirstObjectExtractor.extractFirstJSONObject(from: trimmed) {
                // Strictness: only accept JSON-only output (whitespace is OK).
                if extracted.hasNonWhitespaceOutsideObject == false {
                    return extracted.jsonObject
                }

                // Preserve the original output so the pipeline's strict decoder can fail and route into a repair pass.
                return trimmed
            }

            // If we got a successful exit code but no extractable JSON, return the raw output.
            // The pipeline will attempt to decode; on failure it will run one repair pass.
            return trimmed
        } catch is CancellationError {
            logger.info("Llama cancelled")
            throw CancellationError()
        } catch let error as ProcessRunnerError {
            switch error {
            case .failedToLaunch:
                throw MinuteError.llamaMissing
            case .outputLimitExceeded:
                throw MinuteError.llamaFailed(exitCode: -1, output: "llama output exceeded limit")
            }
        }
    }

    private enum PromptBuilder {
        static func summarizationPrompt(transcript: String, meetingDate: Date) -> String {
            let isoDate = MeetingFileContract.isoDate(meetingDate)

            return """
            You must output JSON only.

            Return exactly one JSON object matching this schema:
            {
              \"title\": string,
              \"date\": \"YYYY-MM-DD\",
              \"summary\": string,
              \"decisions\": [string],
              \"action_items\": [{\"owner\": string, \"task\": string, \"due\": string}],
              \"open_questions\": [string],
              \"key_points\": [string]
            }

            Rules:
            - Output must be a single JSON object.
            - No markdown, no code fences, no commentary.
            - All arrays must be present (use [] if none).
            - date must be \"\(isoDate)\" unless the transcript clearly indicates a different meeting date.
            - action_items.due must be \"YYYY-MM-DD\" or \"\".
            - If the title is unknown, use \"Meeting \(isoDate)\".

            Transcript:
            \(transcript)
            """
        }

        static func repairPrompt(invalidOutput: String) -> String {
            return """
            You must output JSON only.

            The following text was intended to be a JSON object but is invalid or does not match the schema.
            Produce a corrected JSON object that matches this schema exactly:
            {
              \"title\": string,
              \"date\": \"YYYY-MM-DD\",
              \"summary\": string,
              \"decisions\": [string],
              \"action_items\": [{\"owner\": string, \"task\": string, \"due\": string}],
              \"open_questions\": [string],
              \"key_points\": [string]
            }

            Rules:
            - Output must be a single JSON object.
            - No markdown, no code fences, no commentary.
            - All arrays must be present.
            - If a field cannot be recovered, use an empty string or empty array as appropriate.
            - action_items.due must be \"YYYY-MM-DD\" or \"\".

            Invalid output:
            \(invalidOutput)
            """
        }
    }
}

public enum LlamaExecutableLocator {
    /// Returns a usable llama CLI executable URL if available.
    public static func resolveExecutableURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL? {
        if let env = environment["MINUTE_LLAMA_BIN"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }

        // Bundled executable name (task 10 will ensure it is codesigned).
        if let bundled = Bundle.main.url(forResource: "llama", withExtension: nil) {
            return bundled
        }

        // Common alternative name.
        if let bundled = Bundle.main.url(forResource: "llama-cli", withExtension: nil) {
            return bundled
        }

        if let pathURL = resolveFromPath(executableName: "llama", environment: environment) {
            return pathURL
        }

        if let pathURL = resolveFromPath(executableName: "llama-cli", environment: environment) {
            return pathURL
        }

        return nil
    }

    private static func resolveFromPath(executableName: String, environment: [String: String]) -> URL? {
        guard let path = environment["PATH"] else { return nil }
        let fileManager = FileManager.default

        for entry in path.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(entry)).appendingPathComponent(executableName)
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }
}

public enum LlamaModelPaths {
    private static var applicationSupportRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
    }

    /// Default v1 LLM model location.
    ///
    /// Stored under Application Support so the app can run offline after first download.
    public static var defaultLLMModelURL: URL {
        // ~/Library/Application Support/Minute/models/llm/gemma-3-1b-it-Q4_K_M.gguf
        applicationSupportRoot
            .appendingPathComponent("Minute", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("llm", isDirectory: true)
            .appendingPathComponent("gemma-3-1b-it-Q4_K_M.gguf")
    }
}
