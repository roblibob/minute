import AVFoundation
import CoreGraphics
import Foundation
import os

public final class ScreenContextVideoFrameExtractor: @unchecked Sendable {
    private let logger = Logger(subsystem: "roblibob.Minute", category: "screen-context-video")
    private let recognizer: ScreenContextTextRecognizer

    public init(recognizer: ScreenContextTextRecognizer = ScreenContextTextRecognizer()) {
        self.recognizer = recognizer
    }

    public func extractSummary(from sourceURL: URL) async throws -> ScreenContextSummary? {
        let asset = AVURLAsset(url: sourceURL)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard !videoTracks.isEmpty else { return nil }

        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds.isFinite, durationSeconds > 0 else { return nil }

        let maxFrames = 30
        let interval = max(1.0, durationSeconds / Double(maxFrames))
        logger.info("Video screen context sampling started. Duration: \(durationSeconds, privacy: .public)s.")

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1280, height: 720)

        var snapshots: [ScreenContextSnapshot] = []
        var currentTime = 0.0
        var sampledFrames = 0

        while currentTime < durationSeconds {
            try Task.checkCancellation()
            let time = CMTime(seconds: currentTime, preferredTimescale: 600)

            do {
                let image = try generator.copyCGImage(at: time, actualTime: nil)
                let lines = try recognizer.recognizeText(from: image)
                if !lines.isEmpty {
                    let snapshot = ScreenContextSnapshot(
                        capturedAt: Date(),
                        windowTitle: "Video import",
                        extractedLines: lines
                    )
                    snapshots.append(snapshot)
                }
                sampledFrames += 1
            } catch {
                logger.error("Video frame OCR failed: \(String(describing: error), privacy: .public)")
            }

            currentTime += interval
        }

        let summary = ScreenContextAggregator.summarize(snapshots: snapshots)
        logger.info(
            "Video screen context sampling finished. Frames: \(sampledFrames, privacy: .public), snapshots: \(snapshots.count, privacy: .public)."
        )
        return summary.isEmpty ? nil : summary
    }
}
