import Foundation
import Testing
@testable import MinuteCore

struct MeetingPipelineCoordinatorSpeakerTranscriptTests {
    @Test
    func execute_writesSpeakerAttributedTranscriptDeterministically() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let diarization = TestDiarizationService(segments: [
            // Ensures at least one overlap exists so SpeakerAttribution produces segments.
            SpeakerSegment(startSeconds: 0, endSeconds: 6, speakerId: 1),
            SpeakerSegment(startSeconds: 6, endSeconds: 10, speakerId: 2),
        ])

        let transcription = TestTranscriptionService(result: TranscriptionResult(
            text: "Hello. Hi there. Let’s start.",
            segments: [
                TranscriptSegment(startSeconds: 0, endSeconds: 5, text: "Hello."),
                TranscriptSegment(startSeconds: 5, endSeconds: 8, text: "Hi there."),
                TranscriptSegment(startSeconds: 8, endSeconds: 10, text: "Let’s start."),
            ]
        ))

        let coordinator = makeCoordinator(
            vaultRootURL: vaultRootURL,
            diarizationService: diarization,
            transcriptionService: transcription,
            summarizationJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12"),
            repairJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12")
        )

        let contextA = try makePipelineContext(saveAudio: false, saveTranscript: true)
        let contextB = try makePipelineContext(saveAudio: false, saveTranscript: true)

        _ = try await coordinator.execute(context: contextA)
        _ = try await coordinator.execute(context: contextB)

        let contract = MeetingFileContract(folders: contextA.vaultFolders)
        let baseRelative = contract.transcriptRelativePath(date: contextA.startedAt, title: "Weekly Sync")
        let secondRelative = withSuffix(baseRelative, suffix: " (2)")

        let transcriptAURL = vaultRootURL.appendingPathComponent(baseRelative)
        let transcriptBURL = vaultRootURL.appendingPathComponent(secondRelative)

        let a = try String(contentsOf: transcriptAURL)
        let b = try String(contentsOf: transcriptBURL)

        #expect(a.contains("Speaker 1"))
        #expect(a.contains("Speaker 2"))
        expectEqual(a, b)
    }

    @Test
    func execute_whenDiarizationFails_stillWritesTranscript() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let transcription = TestTranscriptionService(result: TranscriptionResult(
            text: "Hello. Hi there.",
            segments: [
                TranscriptSegment(startSeconds: 0, endSeconds: 1, text: "Hello."),
                TranscriptSegment(startSeconds: 1, endSeconds: 2, text: "Hi there."),
            ]
        ))

        let coordinator = makeCoordinator(
            vaultRootURL: vaultRootURL,
            diarizationService: FailingDiarizationService(),
            transcriptionService: transcription,
            summarizationJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12"),
            repairJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12")
        )

        let context = try makePipelineContext(saveAudio: false, saveTranscript: true)
        _ = try await coordinator.execute(context: context)

        let contract = MeetingFileContract(folders: context.vaultFolders)
        let relative = contract.transcriptRelativePath(date: context.startedAt, title: "Weekly Sync")
        let transcriptURL = vaultRootURL.appendingPathComponent(relative)

        let contents = try String(contentsOf: transcriptURL)
        #expect(contents.contains("Hello."))
        #expect(!contents.contains("Speaker 1"))
    }
}

private struct TestModelManager: ModelManaging {
    func ensureModelsPresent(progress: (@Sendable (ModelDownloadProgress) -> Void)?) async throws {
        progress?(ModelDownloadProgress(fractionCompleted: 0, label: "test"))
        progress?(ModelDownloadProgress(fractionCompleted: 1, label: "test"))
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

    func diarize(wavURL: URL, embeddingExportURL: URL?) async throws -> [SpeakerSegment] {
        _ = wavURL
        _ = embeddingExportURL
        return segments
    }
}


private struct FailingDiarizationService: DiarizationServicing {
    func diarize(wavURL: URL, embeddingExportURL: URL?) async throws -> [SpeakerSegment] {
        _ = wavURL
        _ = embeddingExportURL
        throw MinuteError.jsonInvalid
    }
}

private struct TestSummarizationService: SummarizationServicing {
    var summarizationJSON: String
    var repairJSON: String

    func summarize(transcript: String, meetingDate: Date, meetingType: MeetingType) async throws -> String {
        _ = transcript
        _ = meetingDate
        _ = meetingType
        return summarizationJSON
    }

    func classify(transcript: String) async throws -> MeetingType {
        _ = transcript
        return .general
    }

    func repairJSON(_ invalidJSON: String) async throws -> String {
        _ = invalidJSON
        return repairJSON
    }
}

private struct TestVaultWriter: VaultWriting {
    func ensureDirectoryExists(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func writeAtomically(data: Data, to destinationURL: URL) throws {
        try ensureDirectoryExists(destinationURL.deletingLastPathComponent())
        try data.write(to: destinationURL, options: [.atomic])
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
    diarizationService: some DiarizationServicing,
    transcriptionService: some TranscriptionServicing,
    summarizationJSON: String,
    repairJSON: String
) -> MeetingPipelineCoordinator {
    let bookmark = try? VaultAccess.makeBookmarkData(forVaultRootURL: vaultRootURL)
    let store = TestBookmarkStore(bookmark: bookmark)
    let access = VaultAccess(bookmarkStore: store)

    return MeetingPipelineCoordinator(
        transcriptionService: transcriptionService,
        diarizationService: diarizationService,
        summarizationServiceProvider: {
            TestSummarizationService(summarizationJSON: summarizationJSON, repairJSON: repairJSON)
        },
        modelManager: TestModelManager(),
        vaultAccess: access,
        vaultWriter: TestVaultWriter()
    )
}

private func makeTemporaryVault() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-vault-speaker-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makePipelineContext(saveAudio: Bool, saveTranscript: Bool) throws -> PipelineContext {
    let audioTempURL = try makeTemporaryAudioFile()
    let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let stoppedAt = startedAt.addingTimeInterval(60)
    let workingDirectoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-work-speaker-\(UUID().uuidString)", isDirectory: true)

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
        .appendingPathComponent("minute-audio-speaker-\(UUID().uuidString)", isDirectory: true)
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

private func withSuffix(_ relativePath: String, suffix: String) -> String {
    let ns = relativePath as NSString
    let ext = ns.pathExtension
    let base = ns.deletingPathExtension
    return ext.isEmpty ? base + suffix : base + suffix + "." + ext
}
