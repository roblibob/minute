import CoreMedia
import Foundation
@preconcurrency import ScreenCaptureKit
import os

public struct ScreenContextCaptureStatus: Sendable, Equatable {
    public var processedCount: Int
    public var skippedCount: Int
    public var isInferenceRunning: Bool

    public init(processedCount: Int, skippedCount: Int, isInferenceRunning: Bool) {
        self.processedCount = processedCount
        self.skippedCount = skippedCount
        self.isInferenceRunning = isInferenceRunning
    }
}

public struct ScreenContextCaptureResult: Sendable, Equatable {
    public var events: [ScreenContextEvent]
    public var processedCount: Int
    public var skippedCount: Int

    public init(events: [ScreenContextEvent], processedCount: Int, skippedCount: Int) {
        self.events = events
        self.processedCount = processedCount
        self.skippedCount = skippedCount
    }
}

public actor ScreenContextCaptureService {
    private let logger = Logger(subsystem: "roblibob.Minute", category: "screen-context")
    private let inferencer: any ScreenContextInferencing
    private var session: ScreenContextCaptureSession?

    public init(inferencer: any ScreenContextInferencing) {
        self.inferencer = inferencer
    }

    public func startCapture(
        selections: [ScreenContextWindowSelection],
        minimumFrameInterval: TimeInterval = 10.0,
        statusHandler: (@Sendable (ScreenContextCaptureStatus) -> Void)? = nil
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
            inferencer: inferencer,
            minimumFrameInterval: minimumFrameInterval,
            logger: logger,
            statusHandler: statusHandler
        )
    }

    public func stopCapture() async -> ScreenContextCaptureResult? {
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
    private let collector: ScreenContextEventCollector
    private let statusReporter: ScreenContextStatusReporter

    private init(
        captures: [WindowCapture],
        collector: ScreenContextEventCollector,
        statusReporter: ScreenContextStatusReporter,
        logger: Logger
    ) {
        self.captures = captures
        self.collector = collector
        self.statusReporter = statusReporter
        self.logger = logger
    }

    static func start(
        windows: [ResolvedWindow],
        inferencer: any ScreenContextInferencing,
        minimumFrameInterval: TimeInterval,
        logger: Logger,
        statusHandler: (@Sendable (ScreenContextCaptureStatus) -> Void)?
    ) async throws -> ScreenContextCaptureSession {
        let collector = ScreenContextEventCollector(maxEvents: 120)
        let statusReporter = ScreenContextStatusReporter(statusHandler: statusHandler)

        var captures: [WindowCapture] = []
        for resolved in windows {
            let capture = try WindowCapture(
                window: resolved.window,
                windowTitle: resolved.selection.windowTitle,
                inferencer: inferencer,
                collector: collector,
                statusReporter: statusReporter,
                minimumFrameInterval: minimumFrameInterval,
                logger: logger
            )
            try await capture.start()
            captures.append(capture)
        }

        logger.info("Screen context capture started with \(captures.count, privacy: .public) window(s).")
        return ScreenContextCaptureSession(
            captures: captures,
            collector: collector,
            statusReporter: statusReporter,
            logger: logger
        )
    }

    func stop() async -> ScreenContextCaptureResult? {
        for capture in captures {
            await capture.stop()
        }

        await statusReporter.waitForIdle()
        let events = await collector.sortedEvents()
        let status = statusReporter.snapshot()

        logger.info(
            "Screen context capture finished. Events: \(events.count, privacy: .public), processed: \(status.processedCount, privacy: .public), skipped: \(status.skippedCount, privacy: .public)."
        )

        return ScreenContextCaptureResult(
            events: events,
            processedCount: status.processedCount,
            skippedCount: status.skippedCount
        )
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
                return app.bundleIdentifier == selection.bundleIdentifier
            }

            let selectionTitle = selection.windowTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let resolvedWindow: SCWindow?
            if selectionTitle.isEmpty {
                resolvedWindow = matches.first {
                    ($0.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            } else {
                let exact = matches.first { ($0.title ?? "").lowercased() == selectionTitle }
                let contains = matches.first {
                    let windowTitle = ($0.title ?? "").lowercased()
                    return windowTitle.contains(selectionTitle) || selectionTitle.contains(windowTitle)
                }
                resolvedWindow = exact ?? contains
            }

            if let window = resolvedWindow, !usedIDs.contains(window.windowID) {
                usedIDs.insert(window.windowID)
                resolved.append(ResolvedWindow(window: window, selection: selection))
            }
        }

        return resolved
    }

    private static func fetchShareableContent() async throws -> SCShareableContent {
        try await withCheckedThrowingContinuation { continuation in
            SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: false) { content, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let content {
                    continuation.resume(returning: content)
                } else {
                    continuation.resume(throwing: MinuteError.screenCaptureUnavailable)
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
        inferencer: any ScreenContextInferencing,
        collector: ScreenContextEventCollector,
        statusReporter: ScreenContextStatusReporter,
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
            inferencer: inferencer,
            collector: collector,
            statusReporter: statusReporter,
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
        inferencer: any ScreenContextInferencing,
        collector: ScreenContextEventCollector,
        statusReporter: ScreenContextStatusReporter,
        minimumFrameInterval: TimeInterval,
        logger: Logger
    ) {
        self.processor = ScreenContextFrameProcessor(
            windowTitle: windowTitle,
            inferencer: inferencer,
            collector: collector,
            statusReporter: statusReporter,
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
    private let inferencer: any ScreenContextInferencing
    private let collector: ScreenContextEventCollector
    private let statusReporter: ScreenContextStatusReporter
    private let minimumFrameInterval: TimeInterval
    private let logger: Logger

    private var lastCaptureAt: CFAbsoluteTime = 0
    private var firstTimestampSeconds: Double?

    init(
        windowTitle: String,
        inferencer: any ScreenContextInferencing,
        collector: ScreenContextEventCollector,
        statusReporter: ScreenContextStatusReporter,
        minimumFrameInterval: TimeInterval,
        logger: Logger
    ) {
        self.windowTitle = windowTitle
        self.inferencer = inferencer
        self.collector = collector
        self.statusReporter = statusReporter
        self.minimumFrameInterval = minimumFrameInterval
        self.logger = logger
    }

    func process(sampleBuffer: CMSampleBuffer) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastCaptureAt >= minimumFrameInterval else { return }
        if statusReporter.snapshot().isInferenceRunning {
            lastCaptureAt = now
            statusReporter.markSkipped()
            return
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let imageData = ScreenContextImageEncoder.pngData(from: pixelBuffer) else { return }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let rawSeconds = CMTimeGetSeconds(timestamp)
        if firstTimestampSeconds == nil {
            firstTimestampSeconds = rawSeconds
        }
        let timestampSeconds = max(0, rawSeconds - (firstTimestampSeconds ?? rawSeconds))

        lastCaptureAt = now
        statusReporter.markInferenceStarted()

        let windowTitle = windowTitle
        let inferencer = inferencer
        let collector = collector
        let statusReporter = statusReporter
        let logger = logger
        Task {
            defer { statusReporter.markInferenceFinished() }

            do {
                let inference = try await inferencer.inferScreenContext(from: imageData, windowTitle: windowTitle)
                #if DEBUG
                let summary = inference.summaryLine()
                let clipped = summary.isEmpty ? "(empty)" : String(summary.prefix(240))
                logger.info("Screen inference @ \(timestampSeconds, privacy: .public)s: \(clipped, privacy: .private)")
                #endif
                guard !inference.isEmpty else { return }
                let event = ScreenContextEvent(
                    timestampSeconds: timestampSeconds,
                    windowTitle: windowTitle,
                    inference: inference
                )
                await collector.append(event)
            } catch {
                logger.error("Screen inference failed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}

private actor ScreenContextEventCollector {
    private let maxEvents: Int
    private var events: [ScreenContextEvent] = []

    init(maxEvents: Int) {
        self.maxEvents = maxEvents
    }

    func append(_ event: ScreenContextEvent) {
        guard events.count < maxEvents else { return }
        events.append(event)
    }

    func sortedEvents() -> [ScreenContextEvent] {
        events.sorted { $0.timestampSeconds < $1.timestampSeconds }
    }
}

private final class ScreenContextStatusReporter: @unchecked Sendable {
    private let lock = NSLock()
    private var processedCount: Int = 0
    private var skippedCount: Int = 0
    private var inFlightCount: Int = 0
    private let statusHandler: (@Sendable (ScreenContextCaptureStatus) -> Void)?

    init(statusHandler: (@Sendable (ScreenContextCaptureStatus) -> Void)?) {
        self.statusHandler = statusHandler
    }

    func markInferenceStarted() {
        lock.lock()
        inFlightCount += 1
        let status = snapshotLocked()
        lock.unlock()
        statusHandler?(status)
    }

    func markInferenceFinished() {
        lock.lock()
        inFlightCount = max(0, inFlightCount - 1)
        processedCount += 1
        let status = snapshotLocked()
        lock.unlock()
        statusHandler?(status)
    }

    func markSkipped() {
        lock.lock()
        skippedCount += 1
        let status = snapshotLocked()
        lock.unlock()
        statusHandler?(status)
    }

    func snapshot() -> ScreenContextCaptureStatus {
        lock.lock()
        let status = snapshotLocked()
        lock.unlock()
        return status
    }

    func waitForIdle(maximumWaitSeconds: TimeInterval = 5.0) async {
        let deadline = Date().addingTimeInterval(maximumWaitSeconds)
        while true {
            let status = snapshot()
            if !status.isInferenceRunning {
                return
            }
            if Date() >= deadline {
                return
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    private func snapshotLocked() -> ScreenContextCaptureStatus {
        ScreenContextCaptureStatus(
            processedCount: processedCount,
            skippedCount: skippedCount,
            isInferenceRunning: inFlightCount > 0
        )
    }
}
