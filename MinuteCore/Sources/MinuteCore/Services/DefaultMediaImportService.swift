@preconcurrency import AVFoundation
import Foundation
import os
import UniformTypeIdentifiers

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
        let isAudioImport = isAudioURL(sourceURL)

        if let ffmpegURL = ffmpegExecutableURL() {
            do {
                try await convertWithFFmpeg(sourceURL: sourceURL, tempRoot: tempRoot, outputURL: wavURL, ffmpegURL: ffmpegURL)
            } catch {
                logger.error("ffmpeg conversion failed: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
                if isAudioImport {
                    logger.info("Falling back to CoreAudio conversion.")
                    do {
                        try await AudioWavConverter.convertToContractWav(inputURL: sourceURL, outputURL: wavURL)
                    } catch {
                        logger.error("CoreAudio conversion failed: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
                        throw MinuteError.audioExportFailed
                    }
                } else {
                    throw MinuteError.audioExportFailed
                }
            }
        } else if isAudioImport {
            do {
                try await AudioWavConverter.convertToContractWav(inputURL: sourceURL, outputURL: wavURL)
            } catch {
                logger.error("CoreAudio conversion failed: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
                throw MinuteError.audioExportFailed
            }
        } else {
            logger.error("ffmpeg is missing from the app bundle.")
            throw MinuteError.ffmpegMissing
        }

        try ContractWavVerifier.verifyContractWav(at: wavURL)

        try Task.checkCancellation()

        let duration = try ContractWavVerifier.durationSeconds(ofContractWavAt: wavURL)
        let suggestedStartDate = await resolveSuggestedStartDate(asset: asset, sourceURL: sourceURL)

        logger.info("Imported media to WAV: \(wavURL.path, privacy: .public)")

        return MediaImportResult(
            wavURL: wavURL,
            duration: duration,
            suggestedStartDate: suggestedStartDate
        )
    }

    private func isAudioURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !ext.isEmpty else { return false }
        if ext == "wav" || ext == "wave" || ext == "caf" {
            return true
        }
        if let type = UTType(filenameExtension: ext) {
            return type.conforms(to: .audio)
        }
        return false
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

    private func resolveSuggestedStartDate(asset: AVAsset, sourceURL: URL) async -> Date {
        if let date = await resolveDateFromMetadata(asset: asset) {
            return date
        }

        if let creationDate = try? sourceURL.resourceValues(forKeys: [.creationDateKey]).creationDate {
            return creationDate
        }

        if let modifiedDate = try? sourceURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
            return modifiedDate
        }

        return Date()
    }

    private func resolveDateFromMetadata(asset: AVAsset) async -> Date? {
        do {
            let metadata = try await asset.load(.commonMetadata)
            for item in metadata where item.commonKey?.rawValue == AVMetadataKey.commonKeyCreationDate.rawValue {
                if let date = try await item.load(.dateValue) {
                    return date
                }
            }
        } catch {
            logger.debug("Failed to load metadata date: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
        }

        return nil
    }
}
