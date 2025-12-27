import AVFoundation
import CoreGraphics
import Foundation
import os

public struct ScreenContextVideoInferenceResult: Sendable, Equatable {
    public var events: [ScreenContextEvent]
    public var processedCount: Int

    public init(events: [ScreenContextEvent], processedCount: Int) {
        self.events = events
        self.processedCount = processedCount
    }
}

public final class ScreenContextVideoFrameExtractor: @unchecked Sendable {
    private let logger = Logger(subsystem: "roblibob.Minute", category: "screen-context-video")
    private let inferencer: any ScreenContextInferencing

    public init(inferencer: any ScreenContextInferencing) {
        self.inferencer = inferencer
    }

    /// Runs screen-context inference on a video by sampling frames at regular intervals.
    ///
    /// - Parameters:
    ///   - sourceURL: The URL of the video to analyze.
    ///   - intervalSeconds: The interval, in seconds, between sampled frames.
    ///     The default value is `300.0` (5 minutes), which is a conservative choice to
    ///     keep processing time and resource usage bounded for long videos. Callers
    ///     that require denser coverage of the video content (for example, every few
    ///     seconds) should pass a smaller value explicitly.
    /// - Returns: A `ScreenContextVideoInferenceResult` containing all inferred events,
    ///   or `nil` if the asset has no video tracks or an invalid duration.
    public func inferEvents(
        from sourceURL: URL,
        intervalSeconds: TimeInterval = 300.0
    ) async throws -> ScreenContextVideoInferenceResult? {
        let asset = AVURLAsset(url: sourceURL)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard !videoTracks.isEmpty else { return nil }

        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds.isFinite, durationSeconds > 0 else { return nil }

        logger.info("Video screen inference started. Duration: \(durationSeconds, privacy: .public)s.")

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 800, height: 800)

        var events: [ScreenContextEvent] = []
        var processedCount = 0

        var currentTime = 0.0
        while currentTime < durationSeconds {
            try Task.checkCancellation()
            let time = CMTime(seconds: currentTime, preferredTimescale: 600)

            do {
                let image = try generator.copyCGImage(at: time, actualTime: nil)
                guard let imageData = ScreenContextImageEncoder.pngData(from: image, maxDimension: 800) else {
                    currentTime += intervalSeconds
                    continue
                }
                let inference = try await inferencer.inferScreenContext(
                    from: imageData,
                    windowTitle: "Video import"
                )
                #if DEBUG
                let summary = inference.summaryLine()
                let clipped = summary.isEmpty ? "(empty)" : String(summary.prefix(240))
                logger.info("Screen inference (video) @ \(currentTime, privacy: .public)s: \(clipped, privacy: .private)")
                #endif
                if !inference.isEmpty {
                    let event = ScreenContextEvent(
                        timestampSeconds: currentTime,
                        windowTitle: "Video import",
                        inference: inference
                    )
                    events.append(event)
                }
                processedCount += 1
            } catch {
                logger.error("Video frame inference failed: \(String(describing: error), privacy: .public)")
            }

            currentTime += intervalSeconds
        }

        events.sort { $0.timestampSeconds < $1.timestampSeconds }

        logger.info(
            "Video screen inference finished. Processed: \(processedCount, privacy: .public), events: \(events.count, privacy: .public)."
        )

        return ScreenContextVideoInferenceResult(events: events, processedCount: processedCount)
    }
}
