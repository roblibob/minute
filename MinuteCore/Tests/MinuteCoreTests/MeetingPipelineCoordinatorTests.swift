import Foundation
import XCTest
@testable import MinuteCore

final class MeetingPipelineCoordinatorTests: XCTestCase {
    func testExecute_writesOutputsAndReportsProgress() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let context = try makePipelineContext(saveAudio: true, saveTranscript: true)
        let processedAt = Date(timeIntervalSince1970: 1_701_234_567)
        let coordinator = makeCoordinator(
            vaultRootURL: vaultRootURL,
            summarizationJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12"),
            repairJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12"),
            dateProvider: { processedAt }
        )

        let progressStore = ProgressStore()
        let result = try await coordinator.execute(
            context: context,
            progress: { update in
                progressStore.record(update)
            }
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.noteURL.path))
        XCTAssertNotNil(result.audioURL)
        if let audioURL = result.audioURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: audioURL.path))
        }

        let contract = MeetingFileContract(folders: context.vaultFolders)
        let transcriptRelativePath = contract.transcriptRelativePath(date: context.startedAt, title: "Weekly Sync")
        let transcriptURL = vaultRootURL.appendingPathComponent(transcriptRelativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: transcriptURL.path))

        let noteContents = try String(contentsOf: result.noteURL)
        let expectedDate = MeetingNoteDateFormatter.format(processedAt)
        XCTAssertTrue(noteContents.contains("date: \(expectedDate)"))
        XCTAssertFalse(noteContents.contains("date: 2025-01-12"))

        let snapshot = progressStore.snapshot()
        XCTAssertTrue(
            stages(snapshot.stages, containInOrder: [.downloadingModels, .transcribing, .summarizing, .writing])
        )
        XCTAssertNotNil(snapshot.writingExtraction)
    }

    func testExecute_invalidJSON_usesFallbackExtraction() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let context = try makePipelineContext(saveAudio: false, saveTranscript: false)
        let processedAt = Date(timeIntervalSince1970: 1_701_111_111)
        let coordinator = makeCoordinator(
            vaultRootURL: vaultRootURL,
            summarizationJSON: "not json",
            repairJSON: "still not json",
            dateProvider: { processedAt }
        )

        let result = try await coordinator.execute(context: context)

        XCTAssertTrue(result.noteURL.lastPathComponent.contains("Untitled"))
        XCTAssertNil(result.audioURL)

        let noteContents = try String(contentsOf: result.noteURL)
        XCTAssertTrue(noteContents.contains("Failed to structure output"))
    }
}

private final class ProgressStore: @unchecked Sendable {
    private let lock = NSLock()
    private var stages: [PipelineStage] = []
    private var writingExtraction: MeetingExtraction?

    func record(_ update: PipelineProgress) {
        lock.lock()
        stages.append(update.stage)
        if update.stage == .writing {
            writingExtraction = update.extraction
        }
        lock.unlock()
    }

    func snapshot() -> (stages: [PipelineStage], writingExtraction: MeetingExtraction?) {
        lock.lock()
        defer { lock.unlock() }
        return (stages, writingExtraction)
    }
}

private struct TestModelManager: ModelManaging {
    var progressSteps: [Double]

    func ensureModelsPresent(progress: (@Sendable (ModelDownloadProgress) -> Void)?) async throws {
        for step in progressSteps {
            progress?(ModelDownloadProgress(fractionCompleted: step, label: "test"))
        }
    }

    func validateModels() async throws -> ModelValidationResult {
        ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])
    }

    func removeModels(withIDs ids: [String]) async throws {
        _ = ids
    }
}

private struct TestTranscriptionService: TranscriptionServicing {
    var result: TranscriptionResult

    func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        _ = wavURL
        return result
    }
}

private struct TestDiarizationService: DiarizationServicing {
    var segments: [SpeakerSegment]

    func diarize(wavURL: URL) async throws -> [SpeakerSegment] {
        _ = wavURL
        return segments
    }
}

private struct TestSummarizationService: SummarizationServicing {
    var summarizationJSON: String
    var repairJSON: String

    func summarize(transcript: String, meetingDate: Date) async throws -> String {
        _ = transcript
        _ = meetingDate
        return summarizationJSON
    }

    func repairJSON(_ invalidJSON: String) async throws -> String {
        _ = invalidJSON
        return repairJSON
    }
}

private struct TestVaultWriter: VaultWriting {
    func writeAtomically(data: Data, to destinationURL: URL) throws {
        try ensureDirectoryExists(destinationURL.deletingLastPathComponent())
        try data.write(to: destinationURL, options: [.atomic])
    }

    func ensureDirectoryExists(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

private final class TestBookmarkStore: VaultBookmarkStoring {
    private var bookmark: Data?

    init(bookmark: Data?) {
        self.bookmark = bookmark
    }

    func loadVaultRootBookmark() -> Data? {
        bookmark
    }

    func saveVaultRootBookmark(_ bookmark: Data) {
        self.bookmark = bookmark
    }

    func clearVaultRootBookmark() {
        bookmark = nil
    }
}

private func makeCoordinator(
    vaultRootURL: URL,
    summarizationJSON: String,
    repairJSON: String,
    dateProvider: @escaping @Sendable () -> Date = Date.init
) -> MeetingPipelineCoordinator {
    let bookmark = try? VaultAccess.makeBookmarkData(forVaultRootURL: vaultRootURL)
    let store = TestBookmarkStore(bookmark: bookmark)
    let access = VaultAccess(bookmarkStore: store)

    let transcription = TranscriptionResult(
        text: "Hello world",
        segments: [TranscriptSegment(startSeconds: 0, endSeconds: 1, text: "Hello world")]
    )

    return MeetingPipelineCoordinator(
        transcriptionService: TestTranscriptionService(result: transcription),
        diarizationService: TestDiarizationService(segments: []),
        summarizationServiceProvider: {
            TestSummarizationService(summarizationJSON: summarizationJSON, repairJSON: repairJSON)
        },
        modelManager: TestModelManager(progressSteps: [0, 1]),
        vaultAccess: access,
        vaultWriter: TestVaultWriter(),
        dateProvider: dateProvider
    )
}

private func makeTemporaryVault() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-vault-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makePipelineContext(saveAudio: Bool, saveTranscript: Bool) throws -> PipelineContext {
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
        saveAudio: saveAudio,
        saveTranscript: saveTranscript,
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

private func validExtractionJSON(title: String, date: String) -> String {
    return #"""
    {
      "title": "\#(title)",
      "date": "\#(date)",
      "summary": "Summary",
      "decisions": [],
      "action_items": [],
      "open_questions": [],
      "key_points": []
    }
    """#
}

private func stages(_ stages: [PipelineStage], containInOrder expected: [PipelineStage]) -> Bool {
    var index = stages.startIndex
    for stage in expected {
        guard let found = stages[index...].firstIndex(of: stage) else {
            return false
        }
        index = stages.index(after: found)
    }
    return true
}
