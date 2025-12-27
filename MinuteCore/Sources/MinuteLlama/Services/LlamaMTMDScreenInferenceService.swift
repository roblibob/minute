import Foundation
import MinuteCore
import os

public struct LlamaMTMDScreenInferenceConfiguration: Sendable, Equatable {
    public var modelURL: URL
    public var mmprojURL: URL
    public var maxTokens: Int

    public init(
        modelURL: URL,
        mmprojURL: URL,
        maxTokens: Int = 256
    ) {
        self.modelURL = modelURL
        self.mmprojURL = mmprojURL
        self.maxTokens = maxTokens
    }
}

public struct LlamaMTMDScreenInferenceService: ScreenContextInferencing {
    private let configuration: LlamaMTMDScreenInferenceConfiguration
    private let processRunner: any ProcessRunning
    private let logger = Logger(subsystem: "roblibob.Minute", category: "llama-mtmd")

    public init(
        configuration: LlamaMTMDScreenInferenceConfiguration,
        processRunner: any ProcessRunning = DefaultProcessRunner()
    ) {
        self.configuration = configuration
        self.processRunner = processRunner
    }

    public static func liveDefault(
        selectionStore: SummarizationModelSelectionStore = SummarizationModelSelectionStore()
    ) -> LlamaMTMDScreenInferenceService? {
        let model = selectionStore.selectedModel()
        guard let mmprojURL = model.mmprojDestinationURL else { return nil }
        return LlamaMTMDScreenInferenceService(
            configuration: LlamaMTMDScreenInferenceConfiguration(
                modelURL: model.destinationURL,
                mmprojURL: mmprojURL
            )
        )
    }

    public func inferScreenContext(from imageData: Data, windowTitle: String) async throws -> ScreenContextInference {
        try Task.checkCancellation()

        guard FileManager.default.fileExists(atPath: configuration.modelURL.path) else {
            throw MinuteError.modelMissing
        }
        guard FileManager.default.fileExists(atPath: configuration.mmprojURL.path) else {
            throw MinuteError.mmprojMissing
        }
        guard let mtmdURL = mtmdExecutableURL() else {
            throw MinuteError.llamaMTMDMissing
        }

        let prompt = PromptBuilder.screenContextPrompt(windowTitle: windowTitle)
        let imagePath = try writeImagePayload(imageData)
        let tempDirectory = imagePath.deletingLastPathComponent()
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        dumpImageIfNeeded(imageURL: imagePath, windowTitle: windowTitle)

        let args = [
            "-m", configuration.modelURL.path,
            "--mmproj", configuration.mmprojURL.path,
            "--image", imagePath.path,
            "-p", prompt,
            "-n", String(configuration.maxTokens),
            "-lv", "0"
        ]

        let result = try await processRunner.run(
            executableURL: mtmdURL,
            arguments: args,
            environment: nil,
            workingDirectoryURL: nil,
            maximumOutputBytes: 4 * 1024 * 1024
        )

        if result.exitCode != 0 {
            logger.error("llama-mtmd-cli failed: \(result.combinedOutput, privacy: .public)")
            throw MinuteError.llamaMTMDFailed(exitCode: result.exitCode, output: result.combinedOutput)
        }

        #if DEBUG
        if !result.stdout.isEmpty {
            logger.info("llama-mtmd-cli stdout:\n\(result.stdout, privacy: .private)")
        }
        if !result.stderr.isEmpty {
            logger.info("llama-mtmd-cli stderr:\n\(result.stderr, privacy: .private)")
        }
        #endif

        let output = combinedOutput(from: result)
        return ScreenContextInference(text: normalizeOutput(output))
    }
}

private extension LlamaMTMDScreenInferenceService {
    static let dumpTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    func mtmdExecutableURL() -> URL? {
        let fileManager = FileManager.default
        let environment = ProcessInfo.processInfo.environment

        if let env = environment["MINUTE_LLAMA_MTMD_BIN"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }

        if let bundled = Bundle.main.url(forResource: "llama-mtmd-cli", withExtension: nil),
           fileManager.isExecutableFile(atPath: bundled.path) {
            return bundled
        }

        if let executableFolder = Bundle.main.executableURL?.deletingLastPathComponent() {
            let bundledExecutable = executableFolder.appendingPathComponent("llama-mtmd-cli")
            if fileManager.isExecutableFile(atPath: bundledExecutable.path) {
                return bundledExecutable
            }
        }

        return nil
    }

    func writeImagePayload(_ imageData: Data) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-mtmd-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let imageURL = tempDir.appendingPathComponent("frame.png")
        try imageData.write(to: imageURL, options: [.atomic])
        return imageURL
    }

    func dumpImageIfNeeded(imageURL: URL, windowTitle: String) {
        #if !DEBUG
        return
        #else
        let environment = ProcessInfo.processInfo.environment
        let rawFlag = environment["MINUTE_MTMD_DUMP_IMAGES"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let flag = rawFlag, !flag.isEmpty else { return }

        let normalizedFlag = flag.lowercased()
        let truthyValues: Set<String> = ["1", "true", "yes", "y", "on"]
        guard truthyValues.contains(normalizedFlag) else { return }

        let dumpDir: URL
        if let override = environment["MINUTE_MTMD_DUMP_DIR"], !override.isEmpty {
            dumpDir = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            dumpDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("minute-mtmd-dump", isDirectory: true)
        }

        do {
            try FileManager.default.createDirectory(at: dumpDir, withIntermediateDirectories: true)
            let timestamp = Self.dumpTimestampFormatter.string(from: Date())
            let safeTitle = FilenameSanitizer.sanitizeTitle(windowTitle)
            let suffix = String(UUID().uuidString.prefix(8))
            let filename = "screen-\(timestamp)-\(safeTitle)-\(suffix).png"
            let destination = dumpDir.appendingPathComponent(filename)
            try FileManager.default.copyItem(at: imageURL, to: destination)
            logger.info("Dumped screen frame to \(destination.path, privacy: .public)")
        } catch {
            logger.error("Failed to dump screen frame: \(String(describing: error), privacy: .public)")
        }
        #endif
    }
    
    func combinedOutput(from result: ProcessResult) -> String {
        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stdout.isEmpty && !stderr.isEmpty {
            return result.stdout + "\n" + result.stderr
        }
        if !stdout.isEmpty {
            return result.stdout
        }
        if !stderr.isEmpty {
            return result.stderr
        }
        return result.combinedOutput
    }

    func normalizeOutput(_ output: String) -> String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        let lines = trimmed.split(whereSeparator: \.isNewline)
        let cleaned = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { !shouldIgnoreLine($0) }
        guard !cleaned.isEmpty else { return "" }
        return cleaned.joined(separator: " ")
    }

    func shouldIgnoreLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        if lower.hasPrefix("ggml_") || lower.hasPrefix("llama_") {
            return true
        }
        if lower.hasPrefix("warn") || lower.hasPrefix("error") || lower.hasPrefix("info") {
            return true
        }
        if lower.contains("recommendedmaxworkingsetsize") || lower.contains("metal") {
            return true
        }
        if lower.hasPrefix("loading model") || lower.hasPrefix("model") {
            return true
        }
        if lower.contains("tool call") || lower.contains("template bug") {
            return true
        }
        return false
    }
}

private enum PromptBuilder {
    static func screenContextPrompt(windowTitle: String) -> String {
        """
        <image>
        You are a high-density visual data extractor for meeting records.
        Analyze the provided screenshot and the window title.

        ### EXTRACTION PRIORITIES (Order of importance)
        1. **Presentation Content:** If a slide or document is shared, capture the Main Title and key bullet points.
        2. **Context:** If no slide is visible, describe the active activity (e.g., "Live Coding in Xcode", "Reviewing Jira Board").
        3. **Participants:** List visible names of active speakers or attendees (up to 3). Ignore "mute" icons or UI chrome.

        ### OUTPUT RULES
        - Output a single, plain-text line.
        - Max 400 characters.
        - Use this compact format: "[Screen Content], Participating: [Participant Names]"
        - When participants are visible, use: "[Screen Content], Participating: [Participant Names]". If no participants are visible, output just "[Screen Content]" or "[Screen Content], Participating: None".
        - Do not describe physical appearances.
        - If the screen is blank, minimized, or irrelevant, output "No meaningful screen content".

        Window Title: \(windowTitle)
        """
    }
}
