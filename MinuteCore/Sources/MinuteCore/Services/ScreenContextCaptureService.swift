import CoreGraphics
import Foundation
@preconcurrency import ScreenCaptureKit
import os

public struct ScreenContextCaptureStatus: Sendable, Equatable {
    public var processedCount: Int
    public var skippedCount: Int
    public var isInferenceRunning: Bool
    public var isFirstInferenceDeferred: Bool

    public init(
        processedCount: Int,
        skippedCount: Int,
        isInferenceRunning: Bool,
        isFirstInferenceDeferred: Bool
    ) {
        self.processedCount = processedCount
        self.skippedCount = skippedCount
        self.isInferenceRunning = isInferenceRunning
        self.isFirstInferenceDeferred = isFirstInferenceDeferred
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

public struct ScreenContextCapturedFrame: Sendable, Equatable {
    public var imageData: Data
    public var timestampSeconds: Double
    public var windowTitle: String

    public init(imageData: Data, timestampSeconds: Double, windowTitle: String) {
        self.imageData = imageData
        self.timestampSeconds = timestampSeconds
        self.windowTitle = windowTitle
    }
}

public actor ScreenContextCaptureService {
    private let logger = Logger(subsystem: "roblibob.Minute", category: "screen-context")
    private let inferencerProvider: @Sendable () throws -> any ScreenContextInferencing
    private var session: ScreenContextCaptureSession?

    public init(inferencer: any ScreenContextInferencing) {
        self.inferencerProvider = { inferencer }
    }

    public init(inferencerProvider: @escaping @Sendable () throws -> any ScreenContextInferencing) {
        self.inferencerProvider = inferencerProvider
    }

    public func startCapture(
        selections: [ScreenContextWindowSelection],
        minimumFrameInterval: TimeInterval = 10.0,
        timestampOffsetSeconds: TimeInterval = 0,
        processingBusyGate: ProcessingBusyGate? = nil,
        statusHandler: (@Sendable (ScreenContextCaptureStatus) -> Void)? = nil,
        frameHandler: (@Sendable (ScreenContextCapturedFrame) -> Void)? = nil,
        lifecycleEventHandler: (@Sendable (ScreenContextLifecycleEvent) -> Void)? = nil
    ) async throws {
        guard session == nil else { return }
        guard !selections.isEmpty else { return }

        logger.info("Screen context enabled. Resolving \(selections.count, privacy: .public) selected windows.")
        let resolved = try await ScreenContextCaptureSession.resolveWindows(for: selections)
        guard !resolved.isEmpty else {
            logger.info("Screen context capture skipped: no matching windows.")
            return
        }

        let inferencer = try inferencerProvider()
        session = try await ScreenContextCaptureSession.start(
            sources: ScreenContextCaptureSource.makeSources(from: resolved),
            inferencer: inferencer,
            minimumFrameInterval: minimumFrameInterval,
            timestampOffsetSeconds: timestampOffsetSeconds,
            processingBusyGate: processingBusyGate,
            logger: logger,
            statusHandler: statusHandler,
            frameHandler: frameHandler,
            lifecycleEventHandler: lifecycleEventHandler
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

    // Internal testing seam: bypasses ScreenCaptureKit window resolution and uses in-memory capture sources.
    func _testStartCapture(
        sources: [ScreenContextCaptureSource],
        minimumFrameInterval: TimeInterval = 10.0,
        timestampOffsetSeconds: TimeInterval = 0,
        processingBusyGate: ProcessingBusyGate? = nil,
        statusHandler: (@Sendable (ScreenContextCaptureStatus) -> Void)? = nil,
        frameHandler: (@Sendable (ScreenContextCapturedFrame) -> Void)? = nil,
        lifecycleEventHandler: (@Sendable (ScreenContextLifecycleEvent) -> Void)? = nil
    ) async throws {
        guard session == nil else { return }
        guard !sources.isEmpty else { return }

        let inferencer = try inferencerProvider()
        session = try await ScreenContextCaptureSession.start(
            sources: sources,
            inferencer: inferencer,
            minimumFrameInterval: minimumFrameInterval,
            timestampOffsetSeconds: timestampOffsetSeconds,
            processingBusyGate: processingBusyGate,
            logger: logger,
            statusHandler: statusHandler,
            frameHandler: frameHandler,
            lifecycleEventHandler: lifecycleEventHandler
        )
    }
}

struct ScreenContextCaptureSource: Sendable {
    var windowTitle: String
    var captureImageData: @Sendable () async throws -> Data
    var isWindowAvailable: (@Sendable () async -> Bool)?

    init(
        windowTitle: String,
        captureImageData: @escaping @Sendable () async throws -> Data,
        isWindowAvailable: (@Sendable () async -> Bool)? = nil
    ) {
        self.windowTitle = windowTitle
        self.captureImageData = captureImageData
        self.isWindowAvailable = isWindowAvailable
    }

    fileprivate static func makeSources(from windows: [ResolvedWindow]) -> [ScreenContextCaptureSource] {
        windows.map { resolved in
            ScreenContextCaptureSource(
                windowTitle: resolved.selection.windowTitle,
                captureImageData: {
                    try await ScreenContextCaptureSession.captureImageData(for: resolved.window)
                },
                isWindowAvailable: {
                    await ScreenContextCaptureSession.isWindowAvailable(windowID: resolved.window.windowID)
                }
            )
        }
    }
}

private final class ScreenContextCaptureSession: @unchecked Sendable {
    private let logger: Logger
    private let sources: [ScreenContextCaptureSource]
    private let inferencer: any ScreenContextInferencing
    private let collector: ScreenContextEventCollector
    private let statusReporter: ScreenContextStatusReporter
    private let deferrer: FirstScreenInferenceDeferrer?
    private let minimumFrameInterval: TimeInterval
    private let timestampOffsetSeconds: TimeInterval
    private let frameHandler: (@Sendable (ScreenContextCapturedFrame) -> Void)?
    private let lifecycleEventHandler: (@Sendable (ScreenContextLifecycleEvent) -> Void)?
    private var captureTask: Task<Void, Never>?
    private var firstTimestampSeconds: Double?
    private var closedWindowTitlesNotified: Set<String> = []

    private init(
        sources: [ScreenContextCaptureSource],
        inferencer: any ScreenContextInferencing,
        collector: ScreenContextEventCollector,
        statusReporter: ScreenContextStatusReporter,
        deferrer: FirstScreenInferenceDeferrer?,
        minimumFrameInterval: TimeInterval,
        timestampOffsetSeconds: TimeInterval,
        frameHandler: (@Sendable (ScreenContextCapturedFrame) -> Void)?,
        lifecycleEventHandler: (@Sendable (ScreenContextLifecycleEvent) -> Void)?,
        logger: Logger
    ) {
        self.sources = sources
        self.inferencer = inferencer
        self.collector = collector
        self.statusReporter = statusReporter
        self.deferrer = deferrer
        self.minimumFrameInterval = minimumFrameInterval
        self.timestampOffsetSeconds = timestampOffsetSeconds
        self.frameHandler = frameHandler
        self.lifecycleEventHandler = lifecycleEventHandler
        self.logger = logger
    }

    static func start(
        sources: [ScreenContextCaptureSource],
        inferencer: any ScreenContextInferencing,
        minimumFrameInterval: TimeInterval,
        timestampOffsetSeconds: TimeInterval,
        processingBusyGate: ProcessingBusyGate?,
        logger: Logger,
        statusHandler: (@Sendable (ScreenContextCaptureStatus) -> Void)?,
        frameHandler: (@Sendable (ScreenContextCapturedFrame) -> Void)?,
        lifecycleEventHandler: (@Sendable (ScreenContextLifecycleEvent) -> Void)?
    ) async throws -> ScreenContextCaptureSession {
        let collector = ScreenContextEventCollector(maxEvents: 120)
        let statusReporter = ScreenContextStatusReporter(statusHandler: statusHandler)
        let deferrer = processingBusyGate.map { FirstScreenInferenceDeferrer(processingBusyGate: $0) }

        let session = ScreenContextCaptureSession(
            sources: sources,
            inferencer: inferencer,
            collector: collector,
            statusReporter: statusReporter,
            deferrer: deferrer,
            minimumFrameInterval: minimumFrameInterval,
            timestampOffsetSeconds: timestampOffsetSeconds,
            frameHandler: frameHandler,
            lifecycleEventHandler: lifecycleEventHandler,
            logger: logger
        )
        session.startCaptureLoop()

        logger.info("Screen context capture started with \(sources.count, privacy: .public) window(s).")
        return session
    }

    func stop() async -> ScreenContextCaptureResult? {
        captureTask?.cancel()
        captureTask = nil

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
        captureTask?.cancel()
        captureTask = nil
    }

    private func startCaptureLoop() {
        captureTask?.cancel()
        captureTask = Task { [weak self] in
            guard let self else { return }
            await self.captureLoop()
        }
    }

    private func captureLoop() async {
        let intervalSeconds = max(minimumFrameInterval, 1.0)
        let intervalNanos = UInt64(intervalSeconds * 1_000_000_000)

        while !Task.isCancelled {
            await captureOnce()
            try? await Task.sleep(nanoseconds: intervalNanos)
        }
    }

    private func captureOnce() async {
        for source in sources {
            if Task.isCancelled { return }
            if statusReporter.snapshot().isInferenceRunning {
                statusReporter.markSkipped()
                continue
            }

            do {
                let imageData = try await source.captureImageData()
                let now = CFAbsoluteTimeGetCurrent()
                if firstTimestampSeconds == nil {
                    firstTimestampSeconds = now
                }
                let timestampSeconds = ScreenContextTimestampNormalizer.normalize(
                    rawSeconds: now,
                    firstTimestampSeconds: firstTimestampSeconds,
                    offsetSeconds: timestampOffsetSeconds
                )

                if let frameHandler {
                    let frame = ScreenContextCapturedFrame(
                        imageData: imageData,
                        timestampSeconds: timestampSeconds,
                        windowTitle: source.windowTitle
                    )
                    frameHandler(frame)
                }

                if let deferrer {
                    let shouldStart = await deferrer.shouldStartFirstInferenceAttemptNow()
                    statusReporter.setFirstInferenceDeferred(await deferrer.isDeferred)

                    if !shouldStart {
                        statusReporter.markSkipped()
                        continue
                    }
                }

                statusReporter.markInferenceStarted()

                let inferencer = inferencer
                let collector = collector
                let statusReporter = statusReporter
                let logger = logger
                let windowTitle = source.windowTitle
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
                        logger.error("Screen inference failed: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
                    }
                }
            } catch {
                statusReporter.markSkipped()
                if let isWindowAvailable = source.isWindowAvailable {
                    let stillAvailable = await isWindowAvailable()
                    if !stillAvailable {
                        await notifySharedWindowClosedIfNeeded(windowTitle: source.windowTitle)
                    }
                }
                logger.error("Screen context capture failed: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
            }
        }
    }

    private func notifySharedWindowClosedIfNeeded(windowTitle: String) async {
        guard !closedWindowTitlesNotified.contains(windowTitle) else { return }
        closedWindowTitlesNotified.insert(windowTitle)
        lifecycleEventHandler?(
            ScreenContextLifecycleEvent(
                type: .sharedWindowClosed,
                windowTitle: windowTitle
            )
        )
    }

    fileprivate static func captureImageData(for window: SCWindow) async throws -> Data {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = Self.makeScreenshotConfiguration(for: filter)
        let image = try await Self.captureImage(filter: filter, configuration: configuration)
        guard let data = ScreenContextImageEncoder.pngData(from: image) else {
            throw MinuteError.screenCaptureUnavailable
        }
        return data
    }

    fileprivate static func isWindowAvailable(windowID: CGWindowID) async -> Bool {
        do {
            let content = try await fetchShareableContent()
            return content.windows.contains { $0.windowID == windowID }
        } catch {
            return true
        }
    }

    private static func captureImage(
        filter: SCContentFilter,
        configuration: SCStreamConfiguration
    ) async throws -> CGImage {
        try await ScreenCaptureKitAdapter.captureImage(
            contentFilter: filter,
            configuration: configuration,
            fallbackError: MinuteError.screenCaptureUnavailable
        )
    }

    private static func makeScreenshotConfiguration(for filter: SCContentFilter) -> SCStreamConfiguration {
        ScreenCaptureKitAdapter.makeScreenshotConfiguration(
            contentRect: filter.contentRect,
            pointPixelScale: CGFloat(filter.pointPixelScale),
            capturesAudio: false,
            showsCursor: false,
            scalesToFit: false
        )
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
        try await ScreenCaptureKitAdapter.fetchShareableContent(
            excludingDesktopWindows: true,
            onScreenWindowsOnly: false,
            fallbackError: MinuteError.screenCaptureUnavailable
        )
    }
}

private struct ResolvedWindow: Sendable {
    let window: SCWindow
    let selection: ScreenContextWindowSelection
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
    private var isFirstInferenceDeferred: Bool = false
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

    func setFirstInferenceDeferred(_ deferred: Bool) {
        lock.lock()
        isFirstInferenceDeferred = deferred
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
            isInferenceRunning: inFlightCount > 0,
            isFirstInferenceDeferred: isFirstInferenceDeferred
        )
    }
}
