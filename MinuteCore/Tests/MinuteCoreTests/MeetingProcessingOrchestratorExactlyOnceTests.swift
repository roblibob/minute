import Foundation
import Testing
@testable import MinuteCore

struct MeetingProcessingOrchestratorExactlyOnceTests {
    @Test
    func enqueue_duplicateMeetingID_doesNotTriggerDuplicateProcessingRuns() async throws {
        let recorder = ExecutionRecorder()
        let blocker = BlockingPipelineExecutor(recorder: recorder)
        let gate = ProcessingBusyGate()
        let orchestrator = MeetingProcessingOrchestrator(busyGate: gate, executePipeline: blocker.execute)

        let a = UUID()
        let contextA = try makePipelineContext()

        _ = await orchestrator.enqueue(meetingID: a, context: contextA)
        _ = await orchestrator.enqueue(meetingID: a, context: contextA)

        #expect(await orchestrator.snapshot().pendingMeetingID == nil)

        try await blocker.waitUntilBlocked(meetingID: a)
        await blocker.finish(meetingID: a)
        await gate.waitUntilIdle()

        let snapshot = await recorder.snapshot()
        #expect(snapshot.started == [a])
        #expect(snapshot.finished == [a])
    }
}

private actor ExecutionRecorder {
    private(set) var started: [UUID] = []
    private(set) var finished: [UUID] = []

    func recordStart(_ meetingID: UUID) {
        started.append(meetingID)
    }

    func recordFinish(_ meetingID: UUID) {
        finished.append(meetingID)
    }

    func snapshot() -> (started: [UUID], finished: [UUID]) {
        (started, finished)
    }
}

private actor BlockingPipelineExecutor {
    enum WaitError: Error {
        case timeout
    }

    private let recorder: ExecutionRecorder
    private var continuations: [UUID: CheckedContinuation<Void, Never>] = [:]

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
        await withCheckedContinuation { continuation in
            continuations[meetingID] = continuation
        }
        await recorder.recordFinish(meetingID)
        return PipelineResult(noteURL: URL(fileURLWithPath: "/tmp/note.md"), audioURL: nil)
    }

    func finish(meetingID: UUID) {
        continuations.removeValue(forKey: meetingID)?.resume()
    }

    func waitUntilBlocked(meetingID: UUID) async throws {
        let deadline = Date().addingTimeInterval(1.0)

        while continuations[meetingID] == nil {
            if Date() > deadline {
                throw WaitError.timeout
            }
            await Task.yield()
        }
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
