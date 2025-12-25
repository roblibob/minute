import CoreMedia
import Foundation
@preconcurrency import ScreenCaptureKit
import os

public actor ScreenContextCaptureService {
    private let logger = Logger(subsystem: "roblibob.Minute", category: "screen-context")
    private var session: ScreenContextCaptureSession?

    public init() {}

    public func startCapture(
        selections: [ScreenContextWindowSelection],
        minimumFrameInterval: TimeInterval = 1.0
    ) async throws {
        guard session == nil else { return }
        guard !selections.isEmpty else { return }

        logger.info("Screen context enabled. Resolving \(selections.count, privacy: .public) selected windows.")
        let resolved = try await ScreenContextCaptureSession.resolveWindows(for: selections)
        guard !resolved.isEmpty else {
            logger.info("Screen context capture skipped: no matching windows.")
            return
        }

        session = try await ScreenContextCaptureSession.start(
            windows: resolved,
            minimumFrameInterval: minimumFrameInterval,
            logger: logger
        )
    }

    public func stopCapture() async -> ScreenContextSummary? {
        guard let session else { return nil }
        self.session = nil
        return await session.stop()
    }

    public func cancelCapture() async {
        guard let session else { return }
        self.session = nil
        await session.cancel()
    }
}

private final class ScreenContextCaptureSession: @unchecked Sendable {
    private let logger: Logger
    private let captures: [WindowCapture]
    private let collector: ScreenContextSnapshotCollector

    private init(captures: [WindowCapture], collector: ScreenContextSnapshotCollector, logger: Logger) {
        self.captures = captures
        self.collector = collector
        self.logger = logger
    }

    static func start(
        windows: [ResolvedWindow],
        minimumFrameInterval: TimeInterval,
        logger: Logger
    ) async throws -> ScreenContextCaptureSession {
        let collector = ScreenContextSnapshotCollector(maxSnapshots: 90)
        let recognizer = ScreenContextTextRecognizer()

        var captures: [WindowCapture] = []
        for resolved in windows {
            let capture = try WindowCapture(
                window: resolved.window,
                windowTitle: resolved.selection.windowTitle,
                collector: collector,
                recognizer: recognizer,
                minimumFrameInterval: minimumFrameInterval,
                logger: logger
            )
            try await capture.start()
            captures.append(capture)
        }

        logger.info("Screen context capture started with \(captures.count, privacy: .public) window(s).")
        return ScreenContextCaptureSession(captures: captures, collector: collector, logger: logger)
    }

    func stop() async -> ScreenContextSummary? {
        for capture in captures {
            await capture.stop()
        }

        let (summary, stats) = await collector.summaryAndStats()
        logger.info(
            "Screen context capture finished. Snapshots: \(stats.snapshotCount, privacy: .public), lines: \(stats.totalLineCount, privacy: .public)."
        )
        if let summary {
            logger.info(
                "Screen context summary counts: agenda=\(summary.agendaItems.count, privacy: .public), participants=\(summary.participantNames.count, privacy: .public), artifacts=\(summary.sharedArtifacts.count, privacy: .public), headings=\(summary.keyHeadings.count, privacy: .public), notes=\(summary.notes.count, privacy: .public)."
            )
        }
        return summary
    }

    func cancel() async {
        for capture in captures {
            await capture.stop()
        }
    }

    static func resolveWindows(for selections: [ScreenContextWindowSelection]) async throws -> [ResolvedWindow] {
        let content = try await fetchShareableContent()
        var resolved: [ResolvedWindow] = []
        var usedIDs = Set<CGWindowID>()

        for selection in selections {
            let matches = content.windows.filter { window in
                guard let app = window.owningApplication else { return false }
                guard app.bundleIdentifier == selection.bundleIdentifier else { return false }
                let title = window.title ?? ""
                return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }

            let selectionTitle = selection.windowTitle.lowercased()
            let exact = matches.first { ($0.title ?? "").lowercased() == selectionTitle }
            let contains = matches.first {
                let windowTitle = ($0.title ?? "").lowercased()
                return windowTitle.contains(selectionTitle) || selectionTitle.contains(windowTitle)
            }

            if let window = exact ?? contains, !usedIDs.contains(window.windowID) {
                usedIDs.insert(window.windowID)
                resolved.append(ResolvedWindow(window: window, selection: selection))
            }
        }

        return resolved
    }

    private static func fetchShareableContent() async throws -> SCShareableContent {
        try await withCheckedThrowingContinuation { continuation in
            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let content {
                    continuation.resume(returning: content)
                } else {
                    continuation.resume(throwing: MinuteError.audioExportFailed)
                }
            }
        }
    }
}

private struct ResolvedWindow: Sendable {
    let window: SCWindow
    let selection: ScreenContextWindowSelection
}

private final class WindowCapture: NSObject, @unchecked Sendable {
    private let stream: SCStream
    private let output: ScreenContextStreamOutput

    init(
        window: SCWindow,
        windowTitle: String,
        collector: ScreenContextSnapshotCollector,
        recognizer: ScreenContextTextRecognizer,
        minimumFrameInterval: TimeInterval,
        logger: Logger
    ) throws {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = false
        configuration.minimumFrameInterval = CMTime(seconds: minimumFrameInterval, preferredTimescale: 600)
        configuration.queueDepth = 1
        configuration.showsCursor = false

        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        let output = ScreenContextStreamOutput(
            windowTitle: windowTitle,
            collector: collector,
            recognizer: recognizer,
            minimumFrameInterval: minimumFrameInterval,
            logger: logger
        )
        self.stream = stream
        self.output = output

        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: output.queue)
    }

    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            stream.startCapture { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func stop() async {
        _ = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            stream.stopCapture { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

private final class ScreenContextStreamOutput: NSObject, SCStreamOutput {
    let queue = DispatchQueue(label: "roblibob.Minute.screenContextOutput")
    private let processor: ScreenContextFrameProcessor

    init(
        windowTitle: String,
        collector: ScreenContextSnapshotCollector,
        recognizer: ScreenContextTextRecognizer,
        minimumFrameInterval: TimeInterval,
        logger: Logger
    ) {
        self.processor = ScreenContextFrameProcessor(
            windowTitle: windowTitle,
            collector: collector,
            recognizer: recognizer,
            minimumFrameInterval: minimumFrameInterval,
            logger: logger
        )
        super.init()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        processor.process(sampleBuffer: sampleBuffer)
    }
}

private final class ScreenContextFrameProcessor {
    private let windowTitle: String
    private let collector: ScreenContextSnapshotCollector
    private let recognizer: ScreenContextTextRecognizer
    private let minimumFrameInterval: TimeInterval
    private let logger: Logger

    private var lastProcessedAt = Date.distantPast
    private var isProcessing = false
    private var loggedFirstCapture = false

    init(
        windowTitle: String,
        collector: ScreenContextSnapshotCollector,
        recognizer: ScreenContextTextRecognizer,
        minimumFrameInterval: TimeInterval,
        logger: Logger
    ) {
        self.windowTitle = windowTitle
        self.collector = collector
        self.recognizer = recognizer
        self.minimumFrameInterval = minimumFrameInterval
        self.logger = logger
    }

    func process(sampleBuffer: CMSampleBuffer) {
        guard !isProcessing else { return }
        let now = Date()
        guard now.timeIntervalSince(lastProcessedAt) >= minimumFrameInterval else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        isProcessing = true
        defer {
            lastProcessedAt = Date()
            isProcessing = false
        }

        do {
            let lines = try recognizer.recognizeText(from: pixelBuffer)
            guard !lines.isEmpty else { return }
            let snapshot = ScreenContextSnapshot(
                capturedAt: now,
                windowTitle: windowTitle,
                extractedLines: lines
            )
            let collector = collector
            Task {
                await collector.append(snapshot)
            }
            if !loggedFirstCapture {
                loggedFirstCapture = true
                logger.info(
                    "Screen context captured text for window. Lines: \(lines.count, privacy: .public)."
                )
            }
#if DEBUG
            let redacted = ScreenContextDebugRedactor.redact(lines)
            if !redacted.isEmpty {
                let sample = redacted.prefix(3).map { ScreenContextDebugRedactor.truncate($0, maxLength: 120) }
                let combined = sample.joined(separator: " | ")
                logger.debug(
                    "Screen OCR sample (\(redacted.count, privacy: .public) lines): \(combined, privacy: .public)"
                )
            }
#endif
        } catch {
            logger.error("Screen OCR failed: \(String(describing: error), privacy: .public)")
        }
    }
}

private actor ScreenContextSnapshotCollector {
    private let maxSnapshots: Int
    private var snapshots: [ScreenContextSnapshot] = []
    private var totalLineCount: Int = 0

    init(maxSnapshots: Int) {
        self.maxSnapshots = maxSnapshots
    }

    func append(_ snapshot: ScreenContextSnapshot) {
        guard snapshots.count < maxSnapshots else { return }
        snapshots.append(snapshot)
        totalLineCount += snapshot.extractedLines.count
    }

    func summaryAndStats() -> (ScreenContextSummary?, ScreenContextCaptureStats) {
        let summary = ScreenContextAggregator.summarize(snapshots: snapshots)
        let stats = ScreenContextCaptureStats(
            snapshotCount: snapshots.count,
            totalLineCount: totalLineCount
        )
        return (summary.isEmpty ? nil : summary, stats)
    }
}

private struct ScreenContextCaptureStats: Sendable {
    let snapshotCount: Int
    let totalLineCount: Int
}

private enum ScreenContextDebugRedactor {
    private static let emailRegex = try? NSRegularExpression(
        pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
        options: [.caseInsensitive]
    )
    private static let phoneRegex = try? NSRegularExpression(
        pattern: #"\+?\d[\d\-\s]{6,}\d"#,
        options: []
    )

    static func redact(_ lines: [String]) -> [String] {
        lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            var output = trimmed
            if let emailRegex {
                output = emailRegex.stringByReplacingMatches(
                    in: output,
                    range: NSRange(output.startIndex..., in: output),
                    withTemplate: "[redacted]"
                )
            }
            if let phoneRegex {
                output = phoneRegex.stringByReplacingMatches(
                    in: output,
                    range: NSRange(output.startIndex..., in: output),
                    withTemplate: "[redacted]"
                )
            }
            return output
        }
    }

    static func truncate(_ line: String, maxLength: Int) -> String {
        guard line.count > maxLength else { return line }
        let prefix = line.prefix(maxLength)
        return "\(prefix)..."
    }
}
