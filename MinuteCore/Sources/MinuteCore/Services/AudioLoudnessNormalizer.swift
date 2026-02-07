import Foundation
import os

public protocol AudioLoudnessNormalizing: Sendable {
    /// Produces a deterministic, analysis-only loudness-normalized WAV for downstream services.
    ///
    /// - Returns: URL to a temporary normalized WAV. Never modifies the input file.
    func normalizeForAnalysis(inputURL: URL, workingDirectoryURL: URL) async throws -> URL
}

public struct NoOpAudioLoudnessNormalizer: AudioLoudnessNormalizing {
    public init() {}

    public func normalizeForAnalysis(inputURL: URL, workingDirectoryURL: URL) async throws -> URL {
        _ = workingDirectoryURL
        return inputURL
    }
}

public struct AudioLoudnessNormalizer: AudioLoudnessNormalizing {
    public struct LoudnormMeasurements: Sendable, Equatable, Decodable {
        public var measuredI: String
        public var measuredTP: String
        public var measuredLRA: String
        public var measuredThresh: String
        public var offset: String

        private enum CodingKeys: String, CodingKey {
            case measuredI = "measured_I"
            case measuredTP = "measured_TP"
            case measuredLRA = "measured_LRA"
            case measuredThresh = "measured_thresh"
            case offset
        }

        public init(measuredI: String, measuredTP: String, measuredLRA: String, measuredThresh: String, offset: String) {
            self.measuredI = measuredI
            self.measuredTP = measuredTP
            self.measuredLRA = measuredLRA
            self.measuredThresh = measuredThresh
            self.offset = offset
        }
    }

    private let processRunner: any ProcessRunning
    private let environment: [String: String]

    private let logger = Logger(subsystem: "roblibob.Minute", category: "loudness")

    public init(
        processRunner: any ProcessRunning = DefaultProcessRunner(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.processRunner = processRunner
        self.environment = environment
    }

    public func normalizeForAnalysis(inputURL: URL, workingDirectoryURL: URL) async throws -> URL {
        try Task.checkCancellation()

        let ffmpegURL = try FFmpegLocator.locateFFmpegExecutableURL(environment: environment)

        let fileManager = FileManager.default
        try fileManager.createDirectory(at: workingDirectoryURL, withIntermediateDirectories: true)

        let outputURL = workingDirectoryURL.appendingPathComponent("analysis-normalized.wav")
        if fileManager.fileExists(atPath: outputURL.path) {
            try? fileManager.removeItem(at: outputURL)
        }

        let pass1 = try await runPass1(ffmpegURL: ffmpegURL, inputURL: inputURL)
        try Task.checkCancellation()
        try await runPass2(ffmpegURL: ffmpegURL, inputURL: inputURL, outputURL: outputURL, measurements: pass1)

        return outputURL
    }

    public static func pass1Arguments(inputURL: URL) -> [String] {
        [
            "-y",
            "-nostdin",
            "-hide_banner",
            "-nostats",
            "-threads", "1",
            "-filter_threads", "1",
            "-filter_complex_threads", "1",
            "-loglevel", "info",
            "-i", inputURL.path,
            "-vn",
            "-sn",
            "-dn",
            "-af", "loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json",
            "-f", "null",
            "/dev/null",
        ]
    }

    public static func pass2Arguments(inputURL: URL, outputURL: URL, measurements: LoudnormMeasurements) -> [String] {
        let loudnorm = "loudnorm=I=-16:TP=-1.5:LRA=11:linear=true:measured_I=\(measurements.measuredI):measured_TP=\(measurements.measuredTP):measured_LRA=\(measurements.measuredLRA):measured_thresh=\(measurements.measuredThresh):offset=\(measurements.offset)"
        // Keep the filter chain minimal so the bundled ffmpeg can be compiled small.
        // Output encoding flags (-ar/-ac/-c:a) enforce the contract format.
        let resample = "aresample=16000"

        return [
            "-y",
            "-nostdin",
            "-hide_banner",
            "-nostats",
            "-threads", "1",
            "-filter_threads", "1",
            "-filter_complex_threads", "1",
            "-loglevel", "error",
            "-i", inputURL.path,
            "-vn",
            "-sn",
            "-dn",
            "-af", "\(loudnorm),\(resample)",
            "-ac", "1",
            "-ar", "16000",
            "-c:a", "pcm_s16le",
            outputURL.path,
        ]
    }

    private func runPass1(ffmpegURL: URL, inputURL: URL) async throws -> LoudnormMeasurements {
        let args = Self.pass1Arguments(inputURL: inputURL)

        let result = try await processRunner.run(
            executableURL: ffmpegURL,
            arguments: args,
            environment: nil,
            workingDirectoryURL: nil,
            maximumOutputBytes: 2 * 1024 * 1024
        )

        if result.exitCode != 0 {
            logger.error("ffmpeg loudnorm pass 1 failed: \(result.combinedOutput, privacy: .private)")
            throw MinuteError.audioExportFailed
        }

        return try parseLoudnormMeasurements(from: result.stderr)
    }

    private func runPass2(
        ffmpegURL: URL,
        inputURL: URL,
        outputURL: URL,
        measurements: LoudnormMeasurements
    ) async throws {
        let args = Self.pass2Arguments(inputURL: inputURL, outputURL: outputURL, measurements: measurements)

        let result = try await processRunner.run(
            executableURL: ffmpegURL,
            arguments: args,
            environment: nil,
            workingDirectoryURL: nil,
            maximumOutputBytes: 2 * 1024 * 1024
        )

        if result.exitCode != 0 {
            logger.error("ffmpeg loudnorm pass 2 failed: \(result.combinedOutput, privacy: .private)")
            throw MinuteError.audioExportFailed
        }

        // Ensure downstream services see a stable, contract-compliant format.
        try ContractWavVerifier.verifyContractWav(at: outputURL)
    }

    private func parseLoudnormMeasurements(from stderr: String) throws -> LoudnormMeasurements {
        // Find the JSON object that contains loudnorm stats.
        guard let measuredKeyRange = stderr.range(of: "\"measured_I\"") else {
            throw MinuteError.audioExportFailed
        }

        let prefix = stderr[..<measuredKeyRange.lowerBound]
        guard let objectStart = prefix.lastIndex(of: "{") else {
            throw MinuteError.audioExportFailed
        }

        let suffix = stderr[objectStart...]
        guard let objectEnd = suffix.firstIndex(of: "}") else {
            throw MinuteError.audioExportFailed
        }

        let jsonText = String(suffix[...objectEnd])

        do {
            return try JSONDecoder().decode(LoudnormMeasurements.self, from: Data(jsonText.utf8))
        } catch {
            logger.error("Failed to decode loudnorm JSON: \(ErrorHandler.debugMessage(for: error), privacy: .private)")
            throw MinuteError.audioExportFailed
        }
    }
}
