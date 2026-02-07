import Foundation
import Testing
@testable import MinuteCore

struct ScreenContextCaptureServiceDeferralTests {
    @Test
    func firstInference_isDeferredWhileProcessingIsBusy_thenAllowedWhenIdle() async {
        let gate = ProcessingBusyGate()
        let deferrer = FirstScreenInferenceDeferrer(processingBusyGate: gate)

        let token = await gate.beginBusyScope()
        #expect(await deferrer.shouldStartFirstInferenceAttemptNow() == false)
        #expect(await deferrer.isDeferred == true)

        await token.end()

        #expect(await deferrer.shouldStartFirstInferenceAttemptNow() == true)
        #expect(await deferrer.isDeferred == false)
    }

    @Test
    func afterFirstInferenceAttempt_subsequentInferencesAreNotDeferred() async {
        let gate = ProcessingBusyGate()
        let deferrer = FirstScreenInferenceDeferrer(processingBusyGate: gate)

        #expect(await deferrer.shouldStartFirstInferenceAttemptNow() == true)

        let token = await gate.beginBusyScope()
        #expect(await deferrer.shouldStartFirstInferenceAttemptNow() == true)
        await token.end()
    }

    @Test
    func firstInferenceAttempt_isTheFirstAttemptAcrossAnyWindowSelection() async {
        let gate = ProcessingBusyGate()
        let deferrer = FirstScreenInferenceDeferrer(processingBusyGate: gate)

        // Treat the first call as the first "attempt" (e.g. window A).
        #expect(await deferrer.shouldStartFirstInferenceAttemptNow() == true)

        // Subsequent attempts (e.g. window B) are never deferred, even if processing becomes busy.
        let token = await gate.beginBusyScope()
        #expect(await deferrer.shouldStartFirstInferenceAttemptNow() == true)
        await token.end()
    }

    @Test
    func captureContinuesWhileFirstInferenceIsDeferred_thenInferenceRunsAfterIdle() async throws {
        let gate = ProcessingBusyGate()
        let token = await gate.beginBusyScope()

        let inferencer = InferencerSpy()
        let service = ScreenContextCaptureService(inferencer: inferencer)

        let frames = FrameRecorder()
        let statuses = StatusRecorder()

        let source = ScreenContextCaptureSource(
            windowTitle: "Test Window",
            captureImageData: {
                Data([0x01, 0x02, 0x03])
            }
        )

        try await service._testStartCapture(
            sources: [source],
            minimumFrameInterval: 1.0,
            processingBusyGate: gate,
            statusHandler: { status in
                Task { await statuses.append(status) }
            },
            frameHandler: { frame in
                Task { await frames.append(frame) }
            }
        )

        try await Task.sleep(nanoseconds: 1_200_000_000)

        await Task.yield()
        await Task.yield()

        #expect(await frames.count >= 1)
        #expect(await inferencer.callCount == 0)
        #expect(await statuses.last?.isFirstInferenceDeferred == true)

        await token.end()
        try await Task.sleep(nanoseconds: 1_200_000_000)

        await Task.yield()
        await Task.yield()

        #expect(await inferencer.callCount >= 1)
        #expect(await statuses.last?.isFirstInferenceDeferred == false)

        _ = await service.stopCapture()
    }
}

private actor InferencerSpy: ScreenContextInferencing {
    private(set) var callCount: Int = 0

    func inferScreenContext(from imageData: Data, windowTitle: String) async throws -> ScreenContextInference {
        _ = imageData
        _ = windowTitle
        callCount += 1
        return ScreenContextInference(text: "")
    }
}

private actor FrameRecorder {
    private var frames: [ScreenContextCapturedFrame] = []

    var count: Int { frames.count }

    func append(_ frame: ScreenContextCapturedFrame) {
        frames.append(frame)
    }
}

private actor StatusRecorder {
    private var statuses: [ScreenContextCaptureStatus] = []

    var last: ScreenContextCaptureStatus? { statuses.last }

    func append(_ status: ScreenContextCaptureStatus) {
        statuses.append(status)
    }
}
