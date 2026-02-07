import Foundation
import Testing
@testable import MinuteCore

struct MeetingProcessingOrchestratorRetryTests {
    @Test
    func retry_afterFailure_reenqueuesLastFailedMeeting_andSucceeds() async throws {
        let recorder = StartFinishRecorder()
        let executor = FailOnceThenSucceedExecutor(recorder: recorder)
        let gate = ProcessingBusyGate()
        let orchestrator = MeetingProcessingOrchestrator(busyGate: gate, executePipeline: executor.execute)

        let meetingID = UUID()
        let context = try makePipelineContext()

        _ = await orchestrator.enqueue(meetingID: meetingID, context: context)
        await gate.waitUntilIdle()

        let firstOutcome = await orchestrator.snapshot().lastOutcome
        switch firstOutcome {
        case .failed:
            break
        default:
            Issue.record("Expected first run to fail")
        }

        #expect(await recorder.startedSnapshot() == [meetingID])

        #expect(await orchestrator.retryLastFailedOrCanceled() == true)
        await gate.waitUntilIdle()

        let secondOutcome = await orchestrator.snapshot().lastOutcome
        switch secondOutcome {
        case .completed:
            break
        default:
            Issue.record("Expected retry run to complete")
        }

        #expect(await recorder.startedSnapshot() == [meetingID, meetingID])
        #expect(await recorder.finishedSnapshot() == [meetingID])
    }

    @Test
    func retry_afterCancel_reenqueuesLastCanceledMeeting_andSucceeds() async throws {
        let recorder = StartFinishRecorder()
        let executor = CancelThenSucceedExecutor(recorder: recorder)
        let gate = ProcessingBusyGate()
        let orchestrator = MeetingProcessingOrchestrator(busyGate: gate, executePipeline: executor.execute)

        let meetingID = UUID()
        let context = try makePipelineContext()

        _ = await orchestrator.enqueue(meetingID: meetingID, context: context)
        try await recorder.waitUntilStarted(meetingID: meetingID)

        await orchestrator.cancelActiveProcessing(clearPending: false)
        await gate.waitUntilIdle()

        let canceledOutcome = await orchestrator.snapshot().lastOutcome
        switch canceledOutcome {
        case .canceled:
            break
        default:
            Issue.record("Expected first run to be canceled")
        }

        #expect(await orchestrator.retryLastFailedOrCanceled() == true)
        await gate.waitUntilIdle()

        let retriedOutcome = await orchestrator.snapshot().lastOutcome
        switch retriedOutcome {
        case .completed:
            break
        default:
            Issue.record("Expected retry run to complete")
        }

        #expect(await recorder.startedSnapshot() == [meetingID, meetingID])
        #expect(await recorder.finishedSnapshot() == [meetingID])
    }
}

private actor StartFinishRecorder {
    enum WaitError: Error {
        case timeout
    }

    private var started: [UUID] = []
    private var finished: [UUID] = []

    func recordStart(_ meetingID: UUID) {
        started.append(meetingID)
    }

    func recordFinish(_ meetingID: UUID) {
        finished.append(meetingID)
    }

    func startedSnapshot() -> [UUID] {
        started
    }

    func finishedSnapshot() -> [UUID] {
        finished
    }

    func waitUntilStarted(meetingID: UUID) async throws {
        let deadline = Date().addingTimeInterval(1.0)

        while !started.contains(meetingID) {
            if Date() > deadline {
                throw WaitError.timeout
            }
            await Task.yield()
        }
    }
}

private actor FailOnceThenSucceedExecutor {
    enum TestError: Error {
        case syntheticFailure
    }

    private let recorder: StartFinishRecorder
    private var attempts: [UUID: Int] = [:]

    init(recorder: StartFinishRecorder) {
        self.recorder = recorder
    }

    func execute(
        meetingID: UUID,
        context: PipelineContext,
        progress: (@Sendable (PipelineProgress) -> Void)?
    ) async throws -> PipelineResult {
        _ = context
        _ = progress

        await recorder.recordStart(meetingID)

        let nextAttempt = (attempts[meetingID] ?? 0) + 1
        attempts[meetingID] = nextAttempt

        if nextAttempt == 1 {
            throw TestError.syntheticFailure
        }

        await recorder.recordFinish(meetingID)
        return PipelineResult(noteURL: URL(fileURLWithPath: "/tmp/note.md"), audioURL: nil)
    }
}

private actor CancelThenSucceedExecutor {
    private let recorder: StartFinishRecorder
    private var hasCanceledOnce = false

    init(recorder: StartFinishRecorder) {
        self.recorder = recorder
    }

    func execute(
        meetingID: UUID,
        context: PipelineContext,
        progress: (@Sendable (PipelineProgress) -> Void)?
    ) async throws -> PipelineResult {
        _ = context
        _ = progress

        await recorder.recordStart(meetingID)

        if !hasCanceledOnce {
            hasCanceledOnce = true

            while true {
                try Task.checkCancellation()
                await Task.yield()
            }
        }

        await recorder.recordFinish(meetingID)
        return PipelineResult(noteURL: URL(fileURLWithPath: "/tmp/note.md"), audioURL: nil)
    }
}

private func makePipelineContext() throws -> PipelineContext {
    let audioTempURL = try makeTemporaryAudioFile()
    let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let stoppedAt = startedAt.addingTimeInterval(60)
    let workingDirectoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-work-\(UUID().uuidString)", isDirectory: true)

    return PipelineContext(
        vaultFolders: MeetingFileContract.VaultFolders(),
        audioTempURL: audioTempURL,
        audioDurationSeconds: 60,
        startedAt: startedAt,
        stoppedAt: stoppedAt,
        workingDirectoryURL: workingDirectoryURL,
        saveAudio: false,
        saveTranscript: false,
        screenContextEvents: []
    )
}

private func makeTemporaryAudioFile() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-audio-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fileURL = directory.appendingPathComponent("audio.wav")
    try Data([0x00, 0x01]).write(to: fileURL, options: [.atomic])
    return fileURL
}
