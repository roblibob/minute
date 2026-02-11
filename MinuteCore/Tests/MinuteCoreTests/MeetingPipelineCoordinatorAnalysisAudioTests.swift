import Foundation
import Testing
@testable import MinuteCore

struct MeetingPipelineCoordinatorAnalysisAudioTests {
    @Test
    func execute_whenNormalizeAnalysisAudioEnabled_usesNormalizedURLForTranscriptionAndDiarization_andKeepsVaultAudioFromOriginal() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let normalizedURL = try makeTemporaryAudioFile(directoryPrefix: "minute-audio-normalized")
        try Data([0xFF, 0xEE, 0xDD]).write(to: normalizedURL, options: [.atomic])

        let normalizer = RecordingAudioLoudnessNormalizer(normalizedURL: normalizedURL)
        let transcription = CapturingTranscriptionService(result: TranscriptionResult(
            text: "Hello.",
            segments: [TranscriptSegment(startSeconds: 0, endSeconds: 1, text: "Hello.")]
        ))
        let diarization = CapturingDiarizationService(segments: [])

        let coordinator = makeCoordinator(
            vaultRootURL: vaultRootURL,
            diarizationService: diarization,
            transcriptionService: transcription,
            summarizationJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12"),
            repairJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12"),
            audioLoudnessNormalizer: normalizer
        )

        var context = try makePipelineContext(saveAudio: true, saveTranscript: false)
        context.normalizeAnalysisAudio = true

        #expect(FileManager.default.fileExists(atPath: context.audioTempURL.path))
        let originalAudioData = try Data(contentsOf: context.audioTempURL)
        _ = originalAudioData

        let result = try await coordinator.execute(context: context)

        let usedForTranscription = await transcription.lastWavURL
        let usedForDiarization = await diarization.lastWavURL
        #expect(usedForTranscription == .some(normalizedURL))
        #expect(usedForDiarization == .some(normalizedURL))

        #expect(result.audioURL != nil)
        if let audioURL = result.audioURL {
            let vaultAudioData = try Data(contentsOf: audioURL)
            #expect(vaultAudioData == originalAudioData)
        }
    }

    @Test
    func execute_whenNormalizeAnalysisAudioDisabled_doesNotInvokeNormalizer() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let normalizer = FailingAudioLoudnessNormalizer()
        let transcription = CapturingTranscriptionService(result: TranscriptionResult(
            text: "Hello.",
            segments: [TranscriptSegment(startSeconds: 0, endSeconds: 1, text: "Hello.")]
        ))
        let diarization = CapturingDiarizationService(segments: [])

        let coordinator = makeCoordinator(
            vaultRootURL: vaultRootURL,
            diarizationService: diarization,
            transcriptionService: transcription,
            summarizationJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12"),
            repairJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12"),
            audioLoudnessNormalizer: normalizer
        )

        let context = try makePipelineContext(saveAudio: false, saveTranscript: false)
        _ = try await coordinator.execute(context: context)

        let usedForTranscription = await transcription.lastWavURL
        let usedForDiarization = await diarization.lastWavURL
        #expect(usedForTranscription == .some(context.audioTempURL))
        #expect(usedForDiarization == .some(context.audioTempURL))
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

private actor CapturingTranscriptionService: TranscriptionServicing {
    var result: TranscriptionResult
    var lastWavURL: URL?

    init(result: TranscriptionResult) {
        self.result = result
        self.lastWavURL = nil
    }

    func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        lastWavURL = wavURL
        return result
    }
}

private actor CapturingDiarizationService: DiarizationServicing {
    var segments: [SpeakerSegment]
    var lastWavURL: URL?
    var lastEmbeddingExportURL: URL?

    init(segments: [SpeakerSegment]) {
        self.segments = segments
        self.lastWavURL = nil
    }

    func diarize(wavURL: URL, embeddingExportURL: URL?) async throws -> [SpeakerSegment] {
        lastWavURL = wavURL
        lastEmbeddingExportURL = embeddingExportURL
        return segments
    }
}

private struct RecordingAudioLoudnessNormalizer: AudioLoudnessNormalizing {
    let normalizedURL: URL

    func normalizeForAnalysis(inputURL: URL, workingDirectoryURL: URL) async throws -> URL {
        _ = inputURL
        _ = workingDirectoryURL
        return normalizedURL
    }
}

private struct FailingAudioLoudnessNormalizer: AudioLoudnessNormalizing {
    func normalizeForAnalysis(inputURL: URL, workingDirectoryURL: URL) async throws -> URL {
        _ = inputURL
        _ = workingDirectoryURL
        throw MinuteError.audioExportFailed
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
    audioLoudnessNormalizer: any AudioLoudnessNormalizing
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
        audioLoudnessNormalizer: audioLoudnessNormalizer,
        modelManager: TestModelManager(),
        vaultAccess: access,
        vaultWriter: TestVaultWriter()
    )
}

private func makeTemporaryVault() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-vault-analysis-audio-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makePipelineContext(saveAudio: Bool, saveTranscript: Bool) throws -> PipelineContext {
    let audioTempURL = try makeTemporaryAudioFile(directoryPrefix: "minute-audio-analysis")
    let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let stoppedAt = startedAt.addingTimeInterval(60)
    let workingDirectoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-work-analysis-\(UUID().uuidString)", isDirectory: true)

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

private func makeTemporaryAudioFile(directoryPrefix: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(directoryPrefix)-\(UUID().uuidString)", isDirectory: true)
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
