import Foundation
import Testing
@testable import MinuteCore

struct VaultWriteCoverageTests {
    @Test
    func execute_doesNotWriteTranscriptWhenDisabled() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let context = try makePipelineContext(saveAudio: false, saveTranscript: false)
        let coordinator = makeCoordinator(
            vaultRootURL: vaultRootURL,
            summarizationJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12"),
            repairJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12")
        )

        let result = try await coordinator.execute(context: context)

        #expect(FileManager.default.fileExists(atPath: result.noteURL.path))
        #expect(result.audioURL == nil)

        let contract = MeetingFileContract(folders: context.vaultFolders)
        let transcriptRelativePath = contract.transcriptRelativePath(date: context.startedAt, title: "Weekly Sync")
        let transcriptURL = vaultRootURL.appendingPathComponent(transcriptRelativePath)
        #expect(!FileManager.default.fileExists(atPath: transcriptURL.path))
    }

    @Test
    func reprocessMeeting_keepsExistingThreeFileContractStable() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let noteURL = vaultRootURL.appendingPathComponent(ReprocessMeetingFixtures.noteRelativePath)
        let transcriptURL = vaultRootURL.appendingPathComponent(ReprocessMeetingFixtures.transcriptRelativePath)
        let audioURL = vaultRootURL.appendingPathComponent(ReprocessMeetingFixtures.audioRelativePath)

        try FileManager.default.createDirectory(at: noteURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: transcriptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: audioURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(ReprocessMeetingFixtures.noteMarkdown().utf8).write(to: noteURL, options: [.atomic])
        try Data(ReprocessMeetingFixtures.transcriptMarkdown().utf8).write(to: transcriptURL, options: [.atomic])
        try Data([0x01, 0x02]).write(to: audioURL, options: [.atomic])

        let coordinator = makeCoordinator(
            vaultRootURL: vaultRootURL,
            summarizationJSON: validExtractionJSON(title: "Product Review", date: "2026-03-20"),
            repairJSON: validExtractionJSON(title: "Product Review", date: "2026-03-20")
        )

        let request = ReprocessMeetingFixtures.reprocessRequest(in: vaultRootURL)
        _ = try await coordinator.reprocessMeeting(request: request)

        let files = try vaultFileRelativePaths(under: vaultRootURL)
        #expect(files.count == 3)
        #expect(files.contains(ReprocessMeetingFixtures.noteRelativePath))
        #expect(files.contains(ReprocessMeetingFixtures.transcriptRelativePath))
        #expect(files.contains(ReprocessMeetingFixtures.audioRelativePath))
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

private struct TestSummarizationService: SummarizationServicing {
    var summarizationJSON: String
    var repairJSON: String

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
        _ = languageProcessing
        _ = outputLanguage
        return summarizationJSON
    }

    func classify(transcript: String) async throws -> MeetingType {
        return .general
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
    repairJSON: String
) -> MeetingPipelineCoordinator {
    let bookmark = try? VaultAccess.makeBookmarkData(forVaultRootURL: vaultRootURL)
    let store = TestBookmarkStore(bookmark: bookmark)
    let access = VaultAccess(bookmarkStore: store)

    return MeetingPipelineCoordinator(
        transcriptionService: TestTranscriptionService(result: TranscriptionResult(
            text: "Hello world",
            segments: [TranscriptSegment(startSeconds: 0, endSeconds: 1, text: "Hello world")]
        )),
        diarizationService: TestDiarizationService(segments: []),
        summarizationServiceProvider: {
            TestSummarizationService(summarizationJSON: summarizationJSON, repairJSON: repairJSON)
        },
        modelManager: TestModelManager(progressSteps: [0, 1]),
        vaultAccess: access,
        vaultWriter: TestVaultWriter(),
        dateProvider: Date.init
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
    saveTranscript: Bool
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
        screenContextEvents: [],
        transcriptionOverride: nil
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

private func vaultFileRelativePaths(under vaultRootURL: URL) throws -> [String] {
    guard let enumerator = FileManager.default.enumerator(
        at: vaultRootURL,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
    ) else {
        return []
    }

    var paths: [String] = []
    for case let fileURL as URL in enumerator {
        guard fileURL.hasDirectoryPath == false else { continue }
        paths.append(VaultPathNormalizer.relativePath(from: vaultRootURL, to: fileURL))
    }
    return paths.sorted()
}

private struct TestDiarizationService: DiarizationServicing {
    var segments: [SpeakerSegment]

    func diarize(wavURL: URL, embeddingExportURL: URL?) async throws -> [SpeakerSegment] {
        _ = wavURL
        _ = embeddingExportURL
        return segments
    }
}
