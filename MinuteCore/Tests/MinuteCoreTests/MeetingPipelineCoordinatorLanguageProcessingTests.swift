import Foundation
import Testing
@testable import MinuteCore

struct MeetingPipelineCoordinatorLanguageProcessingTests {
    @Test
    func execute_threadsLanguageProcessingIntoSummarization() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let summarizationService = CapturingSummarizationService(
            summarizationJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12"),
            repairJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12")
        )

        let coordinator = try makeCoordinator(
            vaultRootURL: vaultRootURL,
            summarizationService: summarizationService
        )

        let context = try makePipelineContext(
            saveAudio: false,
            saveTranscript: false,
            languageProcessing: .autoPreserve
        )

        _ = try await coordinator.execute(context: context)

        let captured = await summarizationService.lastLanguageProcessing
        #expect(captured == .autoPreserve)
    }

    @Test
    func execute_threadsOutputLanguageIntoSummarization() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let summarizationService = CapturingSummarizationService(
            summarizationJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12"),
            repairJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12")
        )

        let coordinator = try makeCoordinator(
            vaultRootURL: vaultRootURL,
            summarizationService: summarizationService
        )

        let context = try makePipelineContext(
            saveAudio: false,
            saveTranscript: false,
            languageProcessing: .autoToEnglish,
            outputLanguage: .japaneseJapan
        )

        _ = try await coordinator.execute(context: context)

        let captured = await summarizationService.lastOutputLanguage
        #expect(captured == .japaneseJapan)
    }
}

private actor CapturingSummarizationService: SummarizationServicing {
    private let summarizationJSON: String
    private let repairJSON: String

    var lastLanguageProcessing: LanguageProcessingProfile?
    var lastOutputLanguage: OutputLanguage?

    init(summarizationJSON: String, repairJSON: String) {
        self.summarizationJSON = summarizationJSON
        self.repairJSON = repairJSON
    }

    func summarize(
        transcript: String,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage
    ) async throws -> String {
        _ = transcript
        _ = meetingDate
        _ = meetingType
        lastLanguageProcessing = languageProcessing
        lastOutputLanguage = outputLanguage
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
    func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        _ = wavURL
        return TranscriptionResult(
            text: "Hello world",
            segments: [TranscriptSegment(startSeconds: 0, endSeconds: 1, text: "Hello world")]
        )
    }
}

private struct TestDiarizationService: DiarizationServicing {
    func diarize(wavURL: URL, embeddingExportURL: URL?) async throws -> [SpeakerSegment] {
        _ = wavURL
        _ = embeddingExportURL
        return []
    }
}

private struct TestVaultWriter: VaultWriting {
    func writeAtomically(data: Data, to destinationURL: URL) throws {
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destinationURL, options: [.atomic])
    }

    func ensureDirectoryExists(_ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
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
    summarizationService: some SummarizationServicing
) throws -> MeetingPipelineCoordinator {
    let bookmark = try VaultAccess.makeBookmarkData(forVaultRootURL: vaultRootURL)
    let store = TestBookmarkStore(bookmark: bookmark)
    let access = VaultAccess(bookmarkStore: store)

    return MeetingPipelineCoordinator(
        transcriptionService: TestTranscriptionService(),
        diarizationService: TestDiarizationService(),
        summarizationServiceProvider: {
            summarizationService
        },
        modelManager: TestModelManager(),
        vaultAccess: access,
        vaultWriter: TestVaultWriter()
    )
}

private func makeTemporaryVault() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-vault-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makePipelineContext(
    saveAudio: Bool,
    saveTranscript: Bool,
    languageProcessing: LanguageProcessingProfile,
    outputLanguage: OutputLanguage = .defaultSelection
) throws -> PipelineContext {
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
        languageProcessing: languageProcessing,
        outputLanguage: outputLanguage
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
