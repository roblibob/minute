@preconcurrency import AVFoundation
import Foundation
import os

public actor DefaultMediaImportService: MediaImporting {
    private let logger = Logger(subsystem: "roblibob.Minute", category: "media-import")

    public init() {}

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
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw MinuteError.audioExportFailed
        }

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioSourceURL: URL
        if !videoTracks.isEmpty {
            let extractedURL = tempRoot.appendingPathComponent("extracted.m4a")
            try await exportAudio(from: asset, to: extractedURL)
            audioSourceURL = extractedURL
        } else {
            audioSourceURL = sourceURL
        }

        try Task.checkCancellation()

        let wavURL = tempRoot.appendingPathComponent("contract.wav")
        try await AudioWavConverter.convertToContractWav(inputURL: audioSourceURL, outputURL: wavURL)
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

    private func exportAudio(from asset: AVAsset, to outputURL: URL) async throws {
        let logger = logger

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw MinuteError.audioExportFailed
        }

        exportSession.outputFileType = .m4a
        exportSession.outputURL = outputURL

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        try await withTaskCancellationHandler {
            exportSession.cancelExport()
        } operation: {
            try await withCheckedThrowingContinuation { continuation in
                exportSession.exportAsynchronously {
                    switch exportSession.status {
                    case .completed:
                        continuation.resume()
                    case .failed, .cancelled:
                        if exportSession.status == .cancelled {
                            continuation.resume(throwing: CancellationError())
                            return
                        }
                        let message = exportSession.error?.localizedDescription ?? "export failed"
                        logger.error("Audio export failed: \(message, privacy: .public)")
                        continuation.resume(throwing: MinuteError.audioExportFailed)
                    default:
                        continuation.resume(throwing: MinuteError.audioExportFailed)
                    }
                }
            }
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
