import Foundation
import Testing
@testable import MinuteCore

struct OutputContractCoverageTests {
    @Test
    func meetingNoteDateFormatter_isDeterministicWithFixedLocaleAndTimeZone() {
        let calendar = Calendar(identifier: .gregorian)
        let components = DateComponents(calendar: calendar, timeZone: TimeZone(secondsFromGMT: 0), year: 2026, month: 1, day: 2, hour: 3, minute: 4)
        let date = calendar.date(from: components)!

        let locale = Locale(identifier: "en_US_POSIX")
        let timeZone = TimeZone(secondsFromGMT: 0)!
        let formatted = MeetingNoteDateFormatter.format(date, locale: locale, timeZone: timeZone)
        let normalized = formatted.replacingOccurrences(of: "\u{202F}", with: " ")

        expectEqual(normalized, "Jan 2, 2026 at 3:04 AM")
    }

    @Test
    func speakerFrontmatterUpdate_doesNotCreateExtraVaultFilesBeyondContractOutputs() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let coordinator = makeCoordinator(
            vaultRootURL: vaultRootURL,
            summarizationJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12"),
            repairJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12")
        )

        let context = try makePipelineContext(saveAudio: true, saveTranscript: true)
        let result = try await coordinator.execute(context: context)

        #expect(FileManager.default.fileExists(atPath: result.noteURL.path))
        #expect(result.audioURL != nil)

        let filesAfterPipeline = try vaultFileRelativePaths(under: vaultRootURL)
        #expect(filesAfterPipeline.count == 3)

        let transcriptRelativePaths = filesAfterPipeline.filter { $0.contains("/_transcripts/") }
        #expect(transcriptRelativePaths.count == 1)
        if let transcriptRelativePath = transcriptRelativePaths.first {
            let transcriptURL = vaultRootURL.appendingPathComponent(transcriptRelativePath)
            let transcript = try String(contentsOf: transcriptURL, encoding: .utf8)
            #expect(transcript.contains("Hello world"))
            #expect(!transcript.contains("participants:\n"))
            #expect(!transcript.contains("speaker_map:\n"))
            #expect(!transcript.contains("speaker_order:\n"))
        }

        let naming = MeetingSpeakerNamingService(vaultWriter: TestVaultWriter())
        try naming.updateMeetingNote(
            at: result.noteURL,
            ownedFrontmatter: MeetingParticipantFrontmatter(
                participants: ["Alice", "Bob"],
                speakerMap: [1: "Alice", 2: "Bob"],
                speakerOrder: [2, 1]
            )
        )

        let filesAfterFrontmatter = try vaultFileRelativePaths(under: vaultRootURL)
        #expect(filesAfterFrontmatter == filesAfterPipeline)

        let updatedNote = try String(contentsOf: result.noteURL, encoding: .utf8)
        #expect(updatedNote.contains("participants:\n"))
        #expect(updatedNote.contains("speaker_map:\n"))
        #expect(updatedNote.contains("speaker_order:\n"))

        let transcriptRelativePathsAfterFrontmatter = filesAfterFrontmatter.filter { $0.contains("/_transcripts/") }
        #expect(transcriptRelativePathsAfterFrontmatter == transcriptRelativePaths)
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
    summarizationJSON: String,
    repairJSON: String
) -> MeetingPipelineCoordinator {
    let bookmark = try? VaultAccess.makeBookmarkData(forVaultRootURL: vaultRootURL)
    let store = TestBookmarkStore(bookmark: bookmark)
    let access = VaultAccess(bookmarkStore: store)

    return MeetingPipelineCoordinator(
        transcriptionService: TestTranscriptionService(),
        diarizationService: TestDiarizationService(),
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
        .appendingPathComponent("minute-vault-contract-coverage-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makePipelineContext(saveAudio: Bool, saveTranscript: Bool) throws -> PipelineContext {
    let audioTempURL = try makeTemporaryAudioFile()
    let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let stoppedAt = startedAt.addingTimeInterval(60)
    let workingDirectoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-work-contract-coverage-\(UUID().uuidString)", isDirectory: true)

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
        .appendingPathComponent("minute-audio-contract-coverage-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fileURL = directory.appendingPathComponent("audio.wav")
    try Data([0x00, 0x01]).write(to: fileURL, options: [.atomic])
    return fileURL
}

private func validExtractionJSON(title: String, date: String) -> String {
    #"""
    {
      \"title\": \"\#(title)\",
      \"date\": \"\#(date)\",
      \"summary\": \"Summary\",
      \"decisions\": [],
      \"action_items\": [],
      \"open_questions\": [],
      \"key_points\": []
    }
    """#
}

private func vaultFileRelativePaths(under rootURL: URL) throws -> [String] {
    let rootPath = rootURL.standardizedFileURL.path
    guard let enumerator = FileManager.default.enumerator(
        at: rootURL,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    var result: [String] = []
    for case let url as URL in enumerator {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else { continue }

        let filePath = url.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath + "/") else { continue }
        let relative = String(filePath.dropFirst(rootPath.count + 1))
        result.append(relative)
    }
    return result.sorted()
}
