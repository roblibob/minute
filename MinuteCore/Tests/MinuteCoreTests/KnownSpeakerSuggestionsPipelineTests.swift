import Foundation
import Testing
@testable import MinuteCore

struct KnownSpeakerSuggestionsPipelineTests {
    @Test
    func execute_whenKnownSpeakerSuggestionsEnabled_writesParticipantsAndSpeakerMapFrontmatter() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let diarization = ExportWritingDiarizationService(
            segments: [
                SpeakerSegment(startSeconds: 0, endSeconds: 6, speakerId: 1),
                SpeakerSegment(startSeconds: 6, endSeconds: 10, speakerId: 2),
            ],
            exportEntries: [
                OfflineDiarizerEmbeddingExport.Entry(
                    chunkIndex: 0,
                    speakerIndex: 0,
                    startFrame: 0,
                    endFrame: 10,
                    startTime: 0,
                    endTime: 6,
                    embedding256: unitVector(index: 0),
                    cluster: 0
                ),
                OfflineDiarizerEmbeddingExport.Entry(
                    chunkIndex: 0,
                    speakerIndex: 1,
                    startFrame: 11,
                    endFrame: 20,
                    startTime: 6,
                    endTime: 10,
                    embedding256: unitVector(index: 1),
                    cluster: 1
                ),
            ]
        )

        let transcription = TestTranscriptionService(result: TranscriptionResult(
            text: "Hello. Hi.",
            segments: [
                TranscriptSegment(startSeconds: 0, endSeconds: 6, text: "Hello."),
                TranscriptSegment(startSeconds: 6, endSeconds: 10, text: "Hi."),
            ]
        ))

        let speakerProfileStore = SpeakerProfileStore(
            config: .init(storeURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("minute-speaker-profiles-\(UUID().uuidString).json"))
        )

        _ = try await speakerProfileStore.createProfile(
            name: "Alice",
            embedding: unitVector(index: 0),
            embeddingModelVersion: SpeakerEmbeddingModelVersions.fluidAudioOfflineVbx256
        )

        let coordinator = makeCoordinator(
            vaultRootURL: vaultRootURL,
            diarizationService: diarization,
            transcriptionService: transcription,
            summarizationJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12"),
            repairJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12"),
            speakerProfileStore: speakerProfileStore
        )

        let context = try makePipelineContext(saveAudio: true, saveTranscript: true, knownSpeakerSuggestionsEnabled: true)
        _ = try await coordinator.execute(context: context)

        let contract = MeetingFileContract(folders: context.vaultFolders)
        let noteRelative = contract.noteRelativePath(date: context.startedAt, title: "Weekly Sync")
        let transcriptRelative = contract.transcriptRelativePath(date: context.startedAt, title: "Weekly Sync")
        let audioRelative = contract.audioRelativePath(date: context.startedAt, title: "Weekly Sync")

        let noteURL = vaultRootURL.appendingPathComponent(noteRelative)
        let transcriptURL = vaultRootURL.appendingPathComponent(transcriptRelative)
        let audioURL = vaultRootURL.appendingPathComponent(audioRelative)

        #expect(FileManager.default.fileExists(atPath: noteURL.path))
        #expect(FileManager.default.fileExists(atPath: transcriptURL.path))
        #expect(FileManager.default.fileExists(atPath: audioURL.path))

        let note = try String(contentsOf: noteURL)
        #expect(note.contains("participants:"))
        #expect(note.contains("- \"[[Alice]]\""))
        #expect(note.contains("speaker_map:"))
        #expect(note.contains("\"1\": \"Alice\""))

        // Ensure only the contract files exist in the vault.
        let allFiles = try listAllFilesRecursively(root: vaultRootURL)
        #expect(allFiles.count == 3)
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

private actor ExportWritingDiarizationService: DiarizationServicing {
    var segments: [SpeakerSegment]
    var exportEntries: [OfflineDiarizerEmbeddingExport.Entry]

    init(segments: [SpeakerSegment], exportEntries: [OfflineDiarizerEmbeddingExport.Entry]) {
        self.segments = segments
        self.exportEntries = exportEntries
    }

    func diarize(wavURL: URL, embeddingExportURL: URL?) async throws -> [SpeakerSegment] {
        _ = wavURL

        if let embeddingExportURL {
            try FileManager.default.createDirectory(
                at: embeddingExportURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(exportEntries)
            try data.write(to: embeddingExportURL, options: [.atomic])
        }

        return segments
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
    repairJSON: String,
    speakerProfileStore: SpeakerProfileStore
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
        vaultWriter: TestVaultWriter(),
        speakerProfileStore: speakerProfileStore
    )
}

private func makeTemporaryVault() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-vault-known-speaker-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makePipelineContext(saveAudio: Bool, saveTranscript: Bool, knownSpeakerSuggestionsEnabled: Bool) throws -> PipelineContext {
    let audioTempURL = try makeTemporaryAudioFile()
    let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let stoppedAt = startedAt.addingTimeInterval(60)
    let workingDirectoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-work-known-speaker-\(UUID().uuidString)", isDirectory: true)

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
        transcriptionOverride: nil,
        meetingType: .general,
        knownSpeakerSuggestionsEnabled: knownSpeakerSuggestionsEnabled
    )
}

private func makeTemporaryAudioFile() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-audio-known-speaker-\(UUID().uuidString)", isDirectory: true)
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

private func unitVector(index: Int) -> [Float] {
    var v = [Float](repeating: 0, count: OfflineDiarizerEmbeddingExport.embeddingDimension)
    v[index] = 1
    return v
}

private func listAllFilesRecursively(root: URL) throws -> [URL] {
    let fm = FileManager.default
    let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])
    var files: [URL] = []

    while let url = enumerator?.nextObject() as? URL {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        if values.isRegularFile == true {
            files.append(url)
        }
    }

    return files
}
