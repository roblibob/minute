import Foundation
import os

public struct DefaultVaultWriter: VaultWriting {
    public init() {}
    public func writeAtomically(data: Data, to destinationURL: URL) throws {
        try ensureDirectoryExists(destinationURL.deletingLastPathComponent())
        try data.write(to: destinationURL, options: [.atomic])
    }

    public func ensureDirectoryExists(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

// MARK: - Mocks

@preconcurrency
public final class MockAudioService: AudioServicing, AudioLevelMetering, AudioCaptureControlling, @unchecked Sendable {
    private var isRecording = false
    private var microphoneEnabled = true
    private var systemAudioEnabled = true

    public init() {}

    public func startRecording() async throws {
        isRecording = true
    }

    public func cancelRecording() async {
        isRecording = false
    }

    public func stopRecording() async throws -> AudioCaptureResult {
        guard isRecording else {
            throw MinuteError.audioExportFailed
        }

        isRecording = false

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-capture-\(UUID().uuidString).wav")

        try Data().write(to: url, options: [.atomic])
        return AudioCaptureResult(wavURL: url, duration: 0)
    }

    public func convertToContractWav(inputURL: URL, outputURL: URL) async throws {
        let data = try Data(contentsOf: inputURL)
        try data.write(to: outputURL, options: [.atomic])
    }

    public func setLevelHandler(_ handler: (@Sendable (Float) -> Void)?) async {
        _ = handler
    }

    public func setMicrophoneEnabled(_ enabled: Bool) async {
        microphoneEnabled = enabled
    }

    public func setSystemAudioEnabled(_ enabled: Bool) async {
        systemAudioEnabled = enabled
    }
}

public struct MockTranscriptionService: TranscriptionServicing {
    public init() {}
    public func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        try await Task.sleep(nanoseconds: 800_000_000)
        return TranscriptionResult(
            text: "[mock transcript] file=\(wavURL.lastPathComponent)",
            segments: []
        )
    }
}

public struct MockMediaImportService: MediaImporting {
    public init() {}
    public func importMedia(from sourceURL: URL) async throws -> MediaImportResult {
        _ = sourceURL
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-import-\(UUID().uuidString).wav")
        try Data().write(to: url, options: [.atomic])
        return MediaImportResult(wavURL: url, duration: 0, suggestedStartDate: Date())
    }
}

public struct MockRecordingRecoveryService: RecordingRecoveryServicing {
    public init() {}
    public func findRecoverableRecordings() async -> [RecoverableRecording] {
        []
    }

    public func recover(recording: RecoverableRecording) async throws -> RecordingRecoveryResult {
        _ = recording
        throw MinuteError.audioExportFailed
    }

    public func discard(recording: RecoverableRecording) async {
        _ = recording
    }
}

public struct MockDiarizationService: DiarizationServicing {
    public init() {}
    public func diarize(wavURL: URL, embeddingExportURL: URL?) async throws -> [SpeakerSegment] {
        _ = wavURL
        _ = embeddingExportURL
        return []
    }
}

/// Used by the live pipeline when the whisper executable is not yet bundled / configured.
public struct MissingTranscriptionService: TranscriptionServicing {
    public init() {}
    public func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        throw MinuteError.whisperMissing
    }
}

/// Used by the live pipeline when the llama executable is not yet bundled / configured.
public struct MissingSummarizationService: SummarizationServicing {
    public init() {}
    public func summarize(
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
        throw MinuteError.llamaMissing
    }

    public func classify(transcript: String) async throws -> MeetingType {
        throw MinuteError.llamaMissing
    }

    public func repairJSON(_ invalidJSON: String) async throws -> String {
        throw MinuteError.llamaMissing
    }
}

public struct ErrorSummarizationService: SummarizationServicing {
    public var error: MinuteError

    public init(error: MinuteError) {
        self.error = error
    }

    public func summarize(
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
        throw error
    }

    public func classify(transcript: String) async throws -> MeetingType {
        _ = transcript
        throw error
    }

    public func repairJSON(_ invalidJSON: String) async throws -> String {
        _ = invalidJSON
        throw error
    }
}

public struct MissingScreenContextInferenceService: ScreenContextInferencing {
    public init() {}
    public func inferScreenContext(from imageData: Data, windowTitle: String) async throws -> ScreenContextInference {
        _ = imageData
        _ = windowTitle
        throw MinuteError.llamaMTMDMissing
    }
}

public struct ErrorScreenContextInferenceService: ScreenContextInferencing {
    public var error: MinuteError

    public init(error: MinuteError) {
        self.error = error
    }

    public func inferScreenContext(from imageData: Data, windowTitle: String) async throws -> ScreenContextInference {
        _ = imageData
        _ = windowTitle
        throw error
    }
}

public struct MockScreenContextInferenceService: ScreenContextInferencing {
    public init() {}
    public func inferScreenContext(from imageData: Data, windowTitle: String) async throws -> ScreenContextInference {
        _ = imageData
        return ScreenContextInference(text: "Mock screen context from \(windowTitle).")
    }
}

public struct MockSummarizationService: SummarizationServicing {
    public init() {}
    public func summarize(
        transcript: String,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage
    ) async throws -> String {
        try await Task.sleep(nanoseconds: 800_000_000)

        // Do NOT include the transcript in outputs.
        _ = transcript
        _ = languageProcessing
        _ = outputLanguage
        let iso = MinuteISODate.format(meetingDate)
        let title = "Meeting \(iso) (\(meetingType.rawValue))"

        return """
        {
          \"title\": \"\(title)\",
          \"date\": \"\(iso)\",
          \"summary\": \"Mock summary for \(meetingType.rawValue).\",
          \"decisions\": [\"Mock decision\"],
          \"action_items\": [{\"owner\": \"\", \"task\": \"Mock action\"}],
          \"open_questions\": [\"Mock question\"],
          \"key_points\": [\"Mock key point\"]
        }
        """
    }
    
    public func classify(transcript: String) async throws -> MeetingType {
        try await Task.sleep(nanoseconds: 200_000_000)
        return .general
    }

    public func repairJSON(_ invalidJSON: String) async throws -> String {
        try await Task.sleep(nanoseconds: 200_000_000)
        return invalidJSON
    }
}

public struct MockModelManager: ModelManaging {
    public init() {}
    public func ensureModelsPresent(progress: (@Sendable (ModelDownloadProgress) -> Void)?) async throws {
        _ = progress
    }

    public func validateModels() async throws -> ModelValidationResult {
        ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])
    }

    public func removeModels(withIDs ids: [String]) async throws {
        _ = ids
    }
}

public final class MockVocabularyBoostingSettingsStore: VocabularyBoostingSettingsStoring, @unchecked Sendable {
    private var settings: GlobalVocabularyBoostingSettings

    public init(settings: GlobalVocabularyBoostingSettings = .default) {
        self.settings = settings
    }

    public func load() -> GlobalVocabularyBoostingSettings {
        settings
    }

    public func save(_ settings: GlobalVocabularyBoostingSettings) {
        self.settings = settings
    }

    public func clear() {
        settings = .default
    }
}

public struct MockSessionVocabularyResolver: SessionVocabularyResolving {
    public var next: SessionVocabularyResolution?

    public init(next: SessionVocabularyResolution? = nil) {
        self.next = next
    }

    public func resolve(
        globalSettings: GlobalVocabularyBoostingSettings,
        sessionMode: VocabularyBoostingSessionMode,
        sessionCustomInput: String,
        readiness: VocabularyReadinessStatus
    ) -> SessionVocabularyResolution {
        if let next {
            return next
        }
        return SessionVocabularyResolver().resolve(
            globalSettings: globalSettings,
            sessionMode: sessionMode,
            sessionCustomInput: sessionCustomInput,
            readiness: readiness
        )
    }
}

public final class MockMeetingTypeLibraryStore: MeetingTypeLibraryStoring, @unchecked Sendable {
    private var library: MeetingTypeLibrary

    public init(library: MeetingTypeLibrary = .default) {
        self.library = library
    }

    public func load() -> MeetingTypeLibrary {
        library
    }

    public func save(_ library: MeetingTypeLibrary) {
        self.library = library
    }

    @discardableResult
    public func saveValidated(_ library: MeetingTypeLibrary) throws -> MeetingTypeLibrary {
        let validated = try library.validated()
        self.library = validated
        return validated
    }

    public func clear() {
        library = .default
    }
}

public struct MockResolvedPromptBundleResolver: ResolvedPromptBundleResolving {
    public var nextBundle: ResolvedPromptBundle?

    public init(nextBundle: ResolvedPromptBundle? = nil) {
        self.nextBundle = nextBundle
    }

    public func resolvePromptBundle(
        library: MeetingTypeLibrary,
        selection: MeetingTypeSelection,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage,
        autodetectResolvedTypeID: String?
    ) throws -> ResolvedPromptBundle {
        if let nextBundle {
            return nextBundle
        }

        return try ResolvedPromptBundleResolver().resolvePromptBundle(
            library: library,
            selection: selection,
            languageProcessing: languageProcessing,
            outputLanguage: outputLanguage,
            autodetectResolvedTypeID: autodetectResolvedTypeID
        )
    }
}

public actor MockSilenceAutoStopController: SilenceAutoStopControlling {
    public private(set) var snapshot = SilenceStatusSnapshot()

    public init() {}

    public func start(sessionID: UUID, startedAt: Date) async {
        _ = startedAt
        snapshot = SilenceStatusSnapshot(sessionID: sessionID, phase: .monitoring, pendingAutoStop: false)
    }

    public func stop() async {
        snapshot.phase = .inactive
        snapshot.pendingAutoStop = false
    }

    public func ingest(level: Float, at: Date) async {
        _ = level
        _ = at
    }

    public func keepRecording() async {
        snapshot.phase = .monitoring
        snapshot.pendingAutoStop = false
    }

    public func status() async -> SilenceStatusSnapshot {
        snapshot
    }
}

@MainActor
public final class MockRecordingAlertNotifier: RecordingAlertNotifying {
    public private(set) var silenceWarnings: [RecordingAlert] = []
    public private(set) var sharedWindowAlerts: [RecordingAlert] = []

    public init() {}

    public func notifySilenceStopWarning(alert: RecordingAlert) async -> Bool {
        silenceWarnings.append(alert)
        return true
    }

    public func notifySharedWindowClosed(alert: RecordingAlert) async -> Bool {
        sharedWindowAlerts.append(alert)
        return true
    }

    public func clearSilenceStopWarning() async {
        silenceWarnings.removeAll()
    }

    public func clearSharedWindowClosedWarning() async {
        sharedWindowAlerts.removeAll()
    }
}
