import Foundation
import Testing
@testable import MinuteCore

struct MeetingProcessingOrchestratorCancelTests {
    @Test
    func cancelActiveProcessing_setsOutcomeCanceled_andGateBecomesIdle() async throws {
        let recorder = ExecutionRecorder()
        let executor = CancellablePipelineExecutor(recorder: recorder)
        let gate = ProcessingBusyGate()
        let orchestrator = MeetingProcessingOrchestrator(busyGate: gate, executePipeline: executor.execute)

        let a = UUID()
        let contextA = try makePipelineContext()

        _ = await orchestrator.enqueue(meetingID: a, context: contextA)
        try await recorder.waitUntilStarted(meetingID: a)

        #expect(await gate.isBusy == true)

        await orchestrator.cancelActiveProcessing(clearPending: false)
        await gate.waitUntilIdle()

        let snapshot = await orchestrator.snapshot()
        #expect(snapshot.activeMeetingID == nil)
        #expect(snapshot.pendingMeetingID == nil)
        #expect(snapshot.lastOutcome == .canceled)
        #expect(await gate.isBusy == false)
    }

    @Test
    func cancelActiveProcessing_default_keepsPending_andAutoStartsPendingAfterCancel() async throws {
        let recorder = ExecutionRecorder()
        let executor = CancellablePipelineExecutor(recorder: recorder)
        let gate = ProcessingBusyGate()
        let orchestrator = MeetingProcessingOrchestrator(busyGate: gate, executePipeline: executor.execute)

        let a = UUID()
        let b = UUID()
        let contextA = try makePipelineContext()
        let contextB = try makePipelineContext()

        _ = await orchestrator.enqueue(meetingID: a, context: contextA)
        try await recorder.waitUntilStarted(meetingID: a)

        _ = await orchestrator.enqueue(meetingID: b, context: contextB)
        #expect(await orchestrator.snapshot().pendingMeetingID == b)

        await orchestrator.cancelActiveProcessing(clearPending: false)

        // Pending meeting should start after the canceled run finishes.
        try await recorder.waitUntilStarted(meetingID: b)

        let started = await recorder.startedSnapshot()
        #expect(started == [a, b])

        // Cancel the second run as well to end the test deterministically.
        await orchestrator.cancelActiveProcessing(clearPending: false)
        await gate.waitUntilIdle()

        let snapshot = await orchestrator.snapshot()
        #expect(snapshot.activeMeetingID == nil)
        #expect(snapshot.pendingMeetingID == nil)
        #expect(snapshot.lastOutcome == .canceled)
    }

    @Test
    func cancelActiveProcessing_whenClearPending_true_clearsPending_andDoesNotAutoStartPending() async throws {
        let recorder = ExecutionRecorder()
        let executor = CancellablePipelineExecutor(recorder: recorder)
        let gate = ProcessingBusyGate()
        let orchestrator = MeetingProcessingOrchestrator(busyGate: gate, executePipeline: executor.execute)

        let a = UUID()
        let b = UUID()
        let contextA = try makePipelineContext()
        let contextB = try makePipelineContext()

        _ = await orchestrator.enqueue(meetingID: a, context: contextA)
        try await recorder.waitUntilStarted(meetingID: a)

        _ = await orchestrator.enqueue(meetingID: b, context: contextB)
        #expect(await orchestrator.snapshot().pendingMeetingID == b)

        await orchestrator.cancelActiveProcessing(clearPending: true)
        await gate.waitUntilIdle()

        let snapshot = await orchestrator.snapshot()
        #expect(snapshot.activeMeetingID == nil)
        #expect(snapshot.pendingMeetingID == nil)
        #expect(snapshot.lastOutcome == .canceled)

        let started = await recorder.startedSnapshot()
        #expect(started == [a])
    }
}

private actor ExecutionRecorder {
    enum WaitError: Error {
        case timeout
    }

    private(set) var started: [UUID] = []

    func recordStart(_ meetingID: UUID) {
        started.append(meetingID)
    }

    func startedSnapshot() -> [UUID] {
        started
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

private actor CancellablePipelineExecutor {
    private let recorder: ExecutionRecorder

    init(recorder: ExecutionRecorder) {
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

        while true {
            try Task.checkCancellation()
            await Task.yield()
        }

        throw CancellationError()
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
