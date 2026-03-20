import Foundation
import Testing
@testable import MinuteCore

struct MeetingPipelineCoordinatorReprocessingTests {
    @Test
    func reprocessMeeting_overwritesExistingNoteOnly_andPreservesTranscriptAndAudioArtifacts() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let noteURL = vaultRootURL.appendingPathComponent(ReprocessMeetingFixtures.noteRelativePath)
        let transcriptURL = vaultRootURL.appendingPathComponent(ReprocessMeetingFixtures.transcriptRelativePath)
        let audioURL = vaultRootURL.appendingPathComponent(ReprocessMeetingFixtures.audioRelativePath)

        try createFile(at: noteURL, contents: ReprocessMeetingFixtures.noteMarkdown())
        try createFile(at: transcriptURL, contents: ReprocessMeetingFixtures.transcriptMarkdown())
        try FileManager.default.createDirectory(at: audioURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0x01, 0x02, 0x03]).write(to: audioURL, options: [.atomic])

        let transcriptBefore = try Data(contentsOf: transcriptURL)
        let audioBefore = try Data(contentsOf: audioURL)

        let coordinator = makeReprocessCoordinator(
            vaultRootURL: vaultRootURL,
            summarizationJSON: validExtractionJSON(
                title: "Product Review",
                date: "2026-03-20",
                summary: "Recovered planning summary"
            )
        )

        let request = ReprocessMeetingFixtures.reprocessRequest(in: vaultRootURL)
        let result = try await coordinator.reprocessMeeting(request: request)

        expectEqual(result.noteURL.path, noteURL.path)
        let noteMarkdown = try String(contentsOf: noteURL, encoding: .utf8)
        #expect(noteMarkdown.contains("meeting_type: planning"))
        #expect(noteMarkdown.contains("Recovered planning summary"))
        #expect(noteMarkdown.contains("[[Meetings/_audio/2026-03-20 09.41 - Product Review.wav]]"))
        #expect(noteMarkdown.contains("[[Meetings/_transcripts/2026-03-20 09.41 - Product Review.md]]"))

        expectEqual(try Data(contentsOf: transcriptURL), transcriptBefore)
        expectEqual(try Data(contentsOf: audioURL), audioBefore)
    }

    @Test
    func reprocessMeeting_rejectsAutodetectTargetSelection() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let coordinator = makeReprocessCoordinator(
            vaultRootURL: vaultRootURL,
            summarizationJSON: validExtractionJSON(title: "Product Review", date: "2026-03-20")
        )

        let request = ReprocessMeetingFixtures.reprocessRequest(
            in: vaultRootURL,
            targetMeetingTypeId: MeetingType.autodetect.rawValue
        )

        await #expect(throws: MinuteError.self) {
            _ = try await coordinator.reprocessMeeting(request: request)
        }
    }

    @Test
    func reprocessMeeting_allowsCurrentMeetingTypeSelection() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let noteURL = vaultRootURL.appendingPathComponent(ReprocessMeetingFixtures.noteRelativePath)
        let transcriptURL = vaultRootURL.appendingPathComponent(ReprocessMeetingFixtures.transcriptRelativePath)

        try createFile(at: noteURL, contents: ReprocessMeetingFixtures.noteMarkdown())
        try createFile(at: transcriptURL, contents: ReprocessMeetingFixtures.transcriptMarkdown())

        let coordinator = makeReprocessCoordinator(
            vaultRootURL: vaultRootURL,
            summarizationJSON: validExtractionJSON(title: "Product Review", date: "2026-03-20")
        )

        let request = ReprocessMeetingFixtures.reprocessRequest(
            in: vaultRootURL,
            targetMeetingTypeId: MeetingType.general.rawValue,
            currentMeetingTypeId: MeetingType.general.rawValue
        )

        let result = try await coordinator.reprocessMeeting(request: request)

        expectEqual(result.noteURL.path, noteURL.path)
    }

    @Test
    func reprocessMeeting_requiresOverwriteConfirmation() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let noteURL = vaultRootURL.appendingPathComponent(ReprocessMeetingFixtures.noteRelativePath)
        let transcriptURL = vaultRootURL.appendingPathComponent(ReprocessMeetingFixtures.transcriptRelativePath)

        try createFile(at: noteURL, contents: ReprocessMeetingFixtures.noteMarkdown())
        try createFile(at: transcriptURL, contents: ReprocessMeetingFixtures.transcriptMarkdown())

        let coordinator = makeReprocessCoordinator(
            vaultRootURL: vaultRootURL,
            summarizationJSON: validExtractionJSON(title: "Product Review", date: "2026-03-20")
        )

        let request = ReprocessMeetingFixtures.reprocessRequest(
            in: vaultRootURL,
            overwriteConfirmed: false
        )

        await #expect(throws: MinuteError.self) {
            _ = try await coordinator.reprocessMeeting(request: request)
        }
    }

    @Test
    func reprocessMeeting_requiresVaultAccessBeforeSummarizing() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let noteURL = vaultRootURL.appendingPathComponent(ReprocessMeetingFixtures.noteRelativePath)
        let transcriptURL = vaultRootURL.appendingPathComponent(ReprocessMeetingFixtures.transcriptRelativePath)

        try createFile(at: noteURL, contents: ReprocessMeetingFixtures.noteMarkdown())
        try createFile(at: transcriptURL, contents: ReprocessMeetingFixtures.transcriptMarkdown())

        let summarizationService = ReprocessSummarizationServiceSpy(
            summarizationJSON: validExtractionJSON(title: "Product Review", date: "2026-03-20")
        )
        let store = ReprocessBookmarkStore(bookmark: nil)
        let access = VaultAccess(bookmarkStore: store)
        let coordinator = MeetingPipelineCoordinator(
            transcriptionService: TestReprocessTranscriptionService(),
            diarizationService: TestReprocessDiarizationService(),
            summarizationServiceProvider: { summarizationService },
            modelManager: TestReprocessModelManager(),
            vaultAccess: access,
            vaultWriter: TestReprocessVaultWriter(),
            dateProvider: { Date(timeIntervalSince1970: 1_742_462_460) }
        )

        let request = ReprocessMeetingFixtures.reprocessRequest(in: vaultRootURL)

        await #expect(throws: MinuteError.self) {
            _ = try await coordinator.reprocessMeeting(request: request)
        }
        let invocations = await summarizationService.summarizeInvocations
        expectEqual(invocations, 0)
    }

    @Test
    func reprocessMeeting_usesOriginalMeetingDateFromNotePathForSummarization() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let noteURL = vaultRootURL.appendingPathComponent(ReprocessMeetingFixtures.noteRelativePath)
        let transcriptURL = vaultRootURL.appendingPathComponent(ReprocessMeetingFixtures.transcriptRelativePath)

        try createFile(at: noteURL, contents: ReprocessMeetingFixtures.noteMarkdown())
        try createFile(at: transcriptURL, contents: ReprocessMeetingFixtures.transcriptMarkdown())

        let summarizationService = ReprocessSummarizationServiceSpy(
            summarizationJSON: validExtractionJSON(title: "Product Review", date: "2026-03-20")
        )
        let coordinator = makeReprocessCoordinator(
            vaultRootURL: vaultRootURL,
            summarizationServiceProvider: { summarizationService }
        )

        _ = try await coordinator.reprocessMeeting(request: ReprocessMeetingFixtures.reprocessRequest(in: vaultRootURL))

        let meetingDates = await summarizationService.summarizeMeetingDates
        expectEqual(meetingDates.count, 1)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: try #require(meetingDates.first))
        expectEqual(components.year, 2026)
        expectEqual(components.month, 3)
        expectEqual(components.day, 20)
        expectEqual(components.hour, 9)
        expectEqual(components.minute, 41)
    }
}

private func makeReprocessCoordinator(
    vaultRootURL: URL,
    summarizationServiceProvider: @escaping @Sendable () -> any SummarizationServicing
) -> MeetingPipelineCoordinator {
    let bookmark = try? VaultAccess.makeBookmarkData(forVaultRootURL: vaultRootURL)
    let store = ReprocessBookmarkStore(bookmark: bookmark)
    let access = VaultAccess(bookmarkStore: store)

    return MeetingPipelineCoordinator(
        transcriptionService: TestReprocessTranscriptionService(),
        diarizationService: TestReprocessDiarizationService(),
        summarizationServiceProvider: summarizationServiceProvider,
        modelManager: TestReprocessModelManager(),
        vaultAccess: access,
        vaultWriter: TestReprocessVaultWriter(),
        dateProvider: { Date(timeIntervalSince1970: 1_742_462_460) }
    )
}

private func makeReprocessCoordinator(
    vaultRootURL: URL,
    summarizationJSON: String
) -> MeetingPipelineCoordinator {
    makeReprocessCoordinator(
        vaultRootURL: vaultRootURL,
        summarizationServiceProvider: {
            TestReprocessSummarizationService(summarizationJSON: summarizationJSON)
        }
    )
}

private final class ReprocessBookmarkStore: VaultBookmarkStoring {
    private var bookmark: Data?

    init(bookmark: Data?) {
        self.bookmark = bookmark
    }

    func loadVaultRootBookmark() -> Data? { bookmark }
    func saveVaultRootBookmark(_ bookmark: Data) { self.bookmark = bookmark }
    func clearVaultRootBookmark() { bookmark = nil }
}

private struct TestReprocessModelManager: ModelManaging {
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

private struct TestReprocessTranscriptionService: TranscriptionServicing {
    func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        _ = wavURL
        return TranscriptionResult(text: "", segments: [])
    }
}

private struct TestReprocessDiarizationService: DiarizationServicing {
    func diarize(wavURL: URL, embeddingExportURL: URL?) async throws -> [SpeakerSegment] {
        _ = wavURL
        _ = embeddingExportURL
        return []
    }
}

private struct TestReprocessSummarizationService: SummarizationServicing {
    var summarizationJSON: String

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
        _ = transcript
        return .general
    }

    func repairJSON(_ invalidJSON: String) async throws -> String {
        invalidJSON
    }
}

private actor ReprocessSummarizationServiceSpy: SummarizationServicing {
    private(set) var summarizeInvocations: Int = 0
    private(set) var summarizeMeetingDates: [Date] = []
    private let summarizationJSON: String

    init(summarizationJSON: String) {
        self.summarizationJSON = summarizationJSON
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
        _ = languageProcessing
        _ = outputLanguage
        summarizeInvocations += 1
        summarizeMeetingDates.append(meetingDate)
        return summarizationJSON
    }

    func classify(transcript: String) async throws -> MeetingType {
        _ = transcript
        return .general
    }

    func repairJSON(_ invalidJSON: String) async throws -> String {
        invalidJSON
    }
}

private struct TestReprocessVaultWriter: VaultWriting {
    func ensureDirectoryExists(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func writeAtomically(data: Data, to destinationURL: URL) throws {
        try ensureDirectoryExists(destinationURL.deletingLastPathComponent())
        try data.write(to: destinationURL, options: [.atomic])
    }
}

private func makeTemporaryVault() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-reprocess-vault-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func createFile(at url: URL, contents: String) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(contents.utf8).write(to: url, options: [.atomic])
}

private func validExtractionJSON(title: String, date: String, summary: String = "Summary") -> String {
    #"""
    {
      "title": "\#(title)",
      "date": "\#(date)",
      "summary": "\#(summary)",
      "decisions": [],
      "action_items": [],
      "open_questions": [],
      "key_points": []
    }
    """#
}