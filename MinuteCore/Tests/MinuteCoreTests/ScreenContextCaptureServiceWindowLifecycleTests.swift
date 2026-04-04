import Foundation
import Testing
@testable import MinuteCore

struct ScreenContextCaptureServiceWindowLifecycleTests {
    @Test
    func closedWindow_emitsLifecycleEventOnce() async throws {
        let inferencer = MockScreenContextInferenceService()
        let service = ScreenContextCaptureService(inferencer: inferencer)
        let recorder = LifecycleEventRecorder()

        try await service._testStartCapture(
            sources: [makeClosedWindowTestSource()],
            minimumFrameInterval: 1.0,
            lifecycleEventHandler: { event in
                Task { await recorder.append(event) }
            }
        )

        try await Task.sleep(nanoseconds: 150_000_000)
        _ = await service.stopCapture()

        let events = await recorder.events
        #expect(events.count == 1)
        #expect(events.first?.type == .sharedWindowClosed)
    }

    @Test
    func transientFailure_doesNotEmitWindowClosedEvent() async throws {
        let inferencer = MockScreenContextInferenceService()
        let service = ScreenContextCaptureService(inferencer: inferencer)
        let recorder = LifecycleEventRecorder()

        try await service._testStartCapture(
            sources: [makeTransientFailureTestSource()],
            minimumFrameInterval: 1.0,
            lifecycleEventHandler: { event in
                Task { await recorder.append(event) }
            }
        )

        try await Task.sleep(nanoseconds: 150_000_000)
        _ = await service.stopCapture()

        let events = await recorder.events
        #expect(events.isEmpty)
    }

    @Test
    func activeCapture_usesInjectedVisionInferencer() async throws {
        let inferencer = VisionInferencerSpy()
        let service = ScreenContextCaptureService(inferencer: inferencer)

        try await service._testStartCapture(
            sources: [
                ScreenContextCaptureSource(
                    windowTitle: "Slides",
                    captureImageData: { Data([0x01, 0x02, 0x03]) }
                )
            ],
            minimumFrameInterval: 1.0
        )

        try await Task.sleep(nanoseconds: 150_000_000)
        _ = await service.stopCapture()

        let calls = await inferencer.calls
        #expect(calls == ["Slides"])
    }

    @Test
    func captureStart_resolvesInferencerFromProviderForEachSession() async throws {
        let provider = VisionInferencerProviderSpy()
        let service = ScreenContextCaptureService(
            inferencerProvider: {
                provider.makeInferencer()
            }
        )

        try await service._testStartCapture(
            sources: [
                ScreenContextCaptureSource(
                    windowTitle: "Slides",
                    captureImageData: { Data([0x01]) }
                )
            ],
            minimumFrameInterval: 1.0
        )
        try await Task.sleep(nanoseconds: 150_000_000)
        _ = await service.stopCapture()

        try await service._testStartCapture(
            sources: [
                ScreenContextCaptureSource(
                    windowTitle: "Browser",
                    captureImageData: { Data([0x02]) }
                )
            ],
            minimumFrameInterval: 1.0
        )
        try await Task.sleep(nanoseconds: 150_000_000)
        _ = await service.stopCapture()

        let inferencers = provider.snapshotInferencers()
        var resolvedTitles: [[String]] = []
        for inferencer in inferencers {
            resolvedTitles.append(await inferencer.calls)
        }
        #expect(resolvedTitles == [["Slides"], ["Browser"]])
    }

    @Test
    func terminalInferenceFailure_emitsLifecycleEventOnceAndStopsRetrying() async throws {
        let inferencer = TerminalFailureInferencer()
        let service = ScreenContextCaptureService(inferencer: inferencer)
        let recorder = LifecycleEventRecorder()

        try await service._testStartCapture(
            sources: [
                ScreenContextCaptureSource(
                    windowTitle: "Slides",
                    captureImageData: { Data([0x01, 0x02, 0x03]) }
                )
            ],
            minimumFrameInterval: 1.0,
            lifecycleEventHandler: { event in
                Task { await recorder.append(event) }
            }
        )

        try await Task.sleep(nanoseconds: 1_350_000_000)
        _ = await service.stopCapture()

        let events = await recorder.events
        let calls = await inferencer.callCount
        #expect(calls == 1)
        #expect(events.count == 1)
        #expect(events.first?.type == .inferenceUnavailable)
        #expect(events.first?.message?.contains("could not process image input") == true)
    }
}

private actor LifecycleEventRecorder {
    private(set) var events: [ScreenContextLifecycleEvent] = []

    func append(_ event: ScreenContextLifecycleEvent) {
        events.append(event)
    }
}

private actor VisionInferencerSpy: ScreenContextInferencing {
    private(set) var calls: [String] = []

    func inferScreenContext(from imageData: Data, windowTitle: String) async throws -> ScreenContextInference {
        _ = imageData
        calls.append(windowTitle)
        return ScreenContextInference(text: "Vision context for \(windowTitle)")
    }
}

private actor TerminalFailureInferencer: ScreenContextInferencing {
    private(set) var callCount: Int = 0

    func inferScreenContext(from imageData: Data, windowTitle: String) async throws -> ScreenContextInference {
        _ = imageData
        _ = windowTitle
        callCount += 1
        throw MinuteError.llamaMTMDFailed(
            exitCode: 400,
            output: "Error in iterating prediction stream: ValueError: Number of image token positions (1450) does not match number of image features (448) for batch 0"
        )
    }
}

private final class VisionInferencerProviderSpy: @unchecked Sendable {
    private var inferencers: [VisionInferencerSpy] = []
    private let lock = NSLock()

    func makeInferencer() -> VisionInferencerSpy {
        lock.lock()
        defer { lock.unlock() }
        let inferencer = VisionInferencerSpy()
        inferencers.append(inferencer)
        return inferencer
    }

    func snapshotInferencers() -> [VisionInferencerSpy] {
        lock.lock()
        defer { lock.unlock() }
        return inferencers
    }
}
