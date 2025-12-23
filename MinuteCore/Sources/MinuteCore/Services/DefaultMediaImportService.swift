@preconcurrency import AVFoundation
import Foundation
import os

public actor DefaultMediaImportService: MediaImporting {
    private let logger = Logger(subsystem: "roblibob.Minute", category: "media-import")
    private let processRunner: any ProcessRunning

    public init(processRunner: any ProcessRunning = DefaultProcessRunner()) {
        self.processRunner = processRunner
    }

    public func importMedia(from sourceURL: URL) async throws -> MediaImportResult {
        try Task.checkCancellation()

        let access = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if access {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory
            .appendingPathComponent("minute-import-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        let asset = AVURLAsset(url: sourceURL)
        let wavURL = tempRoot.appendingPathComponent("contract.wav")
        guard let ffmpegURL = ffmpegExecutableURL() else {
            logger.error("ffmpeg is missing from the app bundle.")
            throw MinuteError.ffmpegMissing
        }

        do {
            try await convertWithFFmpeg(sourceURL: sourceURL, tempRoot: tempRoot, outputURL: wavURL, ffmpegURL: ffmpegURL)
        } catch {
            logger.error("ffmpeg conversion failed: \(String(describing: error), privacy: .public)")
            throw MinuteError.audioExportFailed
        }

        try ContractWavVerifier.verifyContractWav(at: wavURL)

        try Task.checkCancellation()

        let duration = try ContractWavVerifier.durationSeconds(ofContractWavAt: wavURL)
        let suggestedStartDate = resolveSuggestedStartDate(asset: asset, sourceURL: sourceURL)

        logger.info("Imported media to WAV: \(wavURL.path, privacy: .public)")

        return MediaImportResult(
            wavURL: wavURL,
            duration: duration,
            suggestedStartDate: suggestedStartDate
        )
    }

    private func ffmpegExecutableURL() -> URL? {
        let fileManager = FileManager.default
        let environment = ProcessInfo.processInfo.environment

        if let env = environment["MINUTE_FFMPEG_BIN"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }

        if let bundled = Bundle.main.url(forResource: "ffmpeg", withExtension: nil),
           fileManager.isExecutableFile(atPath: bundled.path) {
            return bundled
        }

        if let executableFolder = Bundle.main.executableURL?.deletingLastPathComponent() {
            let bundledExecutable = executableFolder.appendingPathComponent("ffmpeg")
            if fileManager.isExecutableFile(atPath: bundledExecutable.path) {
                return bundledExecutable
            }
        }

        return nil
    }

    private func convertWithFFmpeg(sourceURL: URL, tempRoot: URL, outputURL: URL, ffmpegURL: URL) async throws {
        let fileManager = FileManager.default
        let ext = sourceURL.pathExtension.isEmpty ? "media" : sourceURL.pathExtension
        let ffmpegInputURL = tempRoot.appendingPathComponent("ffmpeg-input.\(ext)")
        if fileManager.fileExists(atPath: ffmpegInputURL.path) {
            try? fileManager.removeItem(at: ffmpegInputURL)
        }
        try fileManager.copyItem(at: sourceURL, to: ffmpegInputURL)
        try await convertWithFFmpeg(inputURL: ffmpegInputURL, outputURL: outputURL, ffmpegURL: ffmpegURL)
    }

    private func convertWithFFmpeg(inputURL: URL, outputURL: URL, ffmpegURL: URL) async throws {
        let args = [
            "-y",
            "-nostdin",
            "-hide_banner",
            "-loglevel", "error",
            "-i", inputURL.path,
            "-vn",
            "-ac", "1",
            "-ar", String(Int(ContractWavVerifier.requiredSampleRate)),
            "-c:a", "pcm_s16le",
            outputURL.path
        ]

        let result = try await processRunner.run(
            executableURL: ffmpegURL,
            arguments: args,
            environment: nil,
            workingDirectoryURL: nil,
            maximumOutputBytes: 2 * 1024 * 1024
        )

        if result.exitCode != 0 {
            logger.error("ffmpeg failed: \(result.combinedOutput, privacy: .public)")
            throw MinuteError.audioExportFailed
        }
    }

    private func resolveSuggestedStartDate(asset: AVAsset, sourceURL: URL) -> Date {
        for item in asset.commonMetadata {
            if item.commonKey?.rawValue == AVMetadataKey.commonKeyCreationDate.rawValue,
               let date = item.dateValue {
                return date
            }
        }

        if let creationDate = try? sourceURL.resourceValues(forKeys: [.creationDateKey]).creationDate {
            return creationDate
        }

        if let modifiedDate = try? sourceURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
            return modifiedDate
        }

        return Date()
    }
}
