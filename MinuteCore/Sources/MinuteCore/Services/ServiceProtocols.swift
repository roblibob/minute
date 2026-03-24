import Foundation

// MARK: - Vault

public protocol VaultAccessing: Sendable {
    /// Resolves the currently selected vault root URL.
    /// Implementations must ensure security-scoped access is active where required.
    func resolveVaultRootURL() throws -> URL
}

public protocol VaultWriting: Sendable {
    /// Writes data atomically to the vault.
    func writeAtomically(data: Data, to destinationURL: URL) throws

    /// Ensures directories exist.
    func ensureDirectoryExists(_ url: URL) throws
}

// MARK: - Audio

public struct AudioCaptureResult: Sendable {
    public var wavURL: URL
    public var duration: TimeInterval

    public init(wavURL: URL, duration: TimeInterval) {
        self.wavURL = wavURL
        self.duration = duration
    }
}

public protocol AudioServicing: Sendable {
    func startRecording() async throws

    /// Cancels an in-progress recording session and discards any temporary capture artifacts.
    /// Implementations should be best-effort and must not create vault outputs.
    func cancelRecording() async

    /// Stops recording and returns a contract-compliant WAV file URL and its duration.
    func stopRecording() async throws -> AudioCaptureResult

    /// Converts a temporary capture file to a contract-compliant WAV.
    func convertToContractWav(inputURL: URL, outputURL: URL) async throws
}

public protocol AudioLevelMetering: Sendable {
    func setLevelHandler(_ handler: (@Sendable (Float) -> Void)?) async
}

public protocol AudioCaptureControlling: Sendable {
    func setMicrophoneEnabled(_ enabled: Bool) async
    func setSystemAudioEnabled(_ enabled: Bool) async
}

public struct MediaImportResult: Sendable, Equatable {
    public var wavURL: URL
    public var duration: TimeInterval
    public var suggestedStartDate: Date

    public init(wavURL: URL, duration: TimeInterval, suggestedStartDate: Date) {
        self.wavURL = wavURL
        self.duration = duration
        self.suggestedStartDate = suggestedStartDate
    }
}

public protocol MediaImporting: Sendable {
    func importMedia(from sourceURL: URL) async throws -> MediaImportResult
}

// MARK: - Recording recovery

public struct RecoverableRecording: Sendable, Equatable, Identifiable {
    public var id: String
    public var sessionURL: URL
    public var startedAt: Date
    public var captureURL: URL?
    public var systemCaptureURL: URL?
    public var contractWavURL: URL?
    public var microphoneEnabled: Bool?
    public var systemAudioEnabled: Bool?

    public init(
        id: String,
        sessionURL: URL,
        startedAt: Date,
        captureURL: URL?,
        systemCaptureURL: URL?,
        contractWavURL: URL?,
        microphoneEnabled: Bool?,
        systemAudioEnabled: Bool?
    ) {
        self.id = id
        self.sessionURL = sessionURL
        self.startedAt = startedAt
        self.captureURL = captureURL
        self.systemCaptureURL = systemCaptureURL
        self.contractWavURL = contractWavURL
        self.microphoneEnabled = microphoneEnabled
        self.systemAudioEnabled = systemAudioEnabled
    }
}

public struct RecordingRecoveryResult: Sendable, Equatable {
    public var wavURL: URL
    public var duration: TimeInterval
    public var startedAt: Date
    public var stoppedAt: Date

    public init(wavURL: URL, duration: TimeInterval, startedAt: Date, stoppedAt: Date) {
        self.wavURL = wavURL
        self.duration = duration
        self.startedAt = startedAt
        self.stoppedAt = stoppedAt
    }
}

public protocol RecordingRecoveryServicing: Sendable {
    func findRecoverableRecordings() async -> [RecoverableRecording]
    func recover(recording: RecoverableRecording) async throws -> RecordingRecoveryResult
    func discard(recording: RecoverableRecording) async
}

// MARK: - Transcription + Summarization

public protocol TranscriptionServicing: Sendable {
    func transcribe(wavURL: URL) async throws -> TranscriptionResult
}

public struct TranscriptionVocabularySettings: Sendable, Equatable {
    public var mode: VocabularyBoostingSessionMode
    public var terms: [String]
    public var strength: VocabularyBoostingStrength?

    public init(
        mode: VocabularyBoostingSessionMode,
        terms: [String],
        strength: VocabularyBoostingStrength?
    ) {
        self.mode = mode
        self.terms = VocabularyTermEntry.normalizeDisplayTerms(terms)
        self.strength = strength
    }
}

public protocol VocabularyBoostingTranscriptionServicing: TranscriptionServicing {
    func transcribe(
        wavURL: URL,
        vocabulary: TranscriptionVocabularySettings?
    ) async throws -> TranscriptionResult
}

public protocol DiarizationServicing: Sendable {
    func diarize(wavURL: URL, embeddingExportURL: URL?) async throws -> [SpeakerSegment]
}

public protocol SummarizationServicing: Sendable {
    /// Returns raw JSON produced by the model.
    func summarize(
        transcript: String,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage
    ) async throws -> String

    /// Returns raw JSON produced by the model, optionally using a pre-resolved prompt bundle.
    func summarize(
        transcript: String,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage,
        resolvedPromptBundle: ResolvedPromptBundle?
    ) async throws -> String

    /// Classifies the meeting type based on the transcript.
    func classify(
        transcript: String
    ) async throws -> MeetingType

    /// Classifies to a dynamic candidate set (built-in + optional custom type labels).
    /// Returns a stable type identifier and falls back to `fallbackTypeID` on uncertain output.
    func classify(
        transcript: String,
        candidates: [MeetingTypeClassifierCandidate],
        fallbackTypeID: String
    ) async throws -> String

    /// Attempts to repair invalid JSON to match the schema.
    func repairJSON(_ invalidJSON: String) async throws -> String
}

public struct SummarizationRuntimeChunk: Sendable, Equatable {
    public var transcript: String
    public var tokenCount: Int

    public init(transcript: String, tokenCount: Int) {
        self.transcript = transcript
        self.tokenCount = tokenCount
    }
}

public struct SummarizationRuntimePassPlan: Sendable, Equatable {
    public var contextWindowTokens: Int
    public var reservedOutputTokens: Int
    public var safetyMarginTokens: Int
    public var promptOverheadTokens: Int
    public var availableInputTokensPerPass: Int
    public var estimatedTotalInputTokens: Int
    public var chunks: [SummarizationRuntimeChunk]

    public init(
        contextWindowTokens: Int,
        reservedOutputTokens: Int,
        safetyMarginTokens: Int,
        promptOverheadTokens: Int,
        availableInputTokensPerPass: Int,
        estimatedTotalInputTokens: Int,
        chunks: [SummarizationRuntimeChunk]
    ) {
        self.contextWindowTokens = contextWindowTokens
        self.reservedOutputTokens = reservedOutputTokens
        self.safetyMarginTokens = safetyMarginTokens
        self.promptOverheadTokens = promptOverheadTokens
        self.availableInputTokensPerPass = availableInputTokensPerPass
        self.estimatedTotalInputTokens = estimatedTotalInputTokens
        self.chunks = chunks
    }
}

public protocol RuntimeAwareSummarizationServicing: SummarizationServicing {
    /// Optionally refines transcript chunking after the underlying runtime is loaded and its tokenizer is available.
    func makeRuntimePassPlan(
        transcript: String,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage,
        resolvedPromptBundle: ResolvedPromptBundle?
    ) async throws -> SummarizationRuntimePassPlan

    /// Summarizes a single pass while allowing the implementation to reuse already-loaded runtime state.
    func summarizePass(
        transcriptChunk: String,
        previousSummaryJSON: String?,
        passIndex: Int,
        totalPasses: Int,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage,
        resolvedPromptBundle: ResolvedPromptBundle?
    ) async throws -> String
}

public extension SummarizationServicing {
    func summarize(
        transcript: String,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage,
        resolvedPromptBundle: ResolvedPromptBundle?
    ) async throws -> String {
        _ = resolvedPromptBundle
        return try await summarize(
            transcript: transcript,
            meetingDate: meetingDate,
            meetingType: meetingType,
            languageProcessing: languageProcessing,
            outputLanguage: outputLanguage
        )
    }

    func classify(
        transcript: String,
        candidates: [MeetingTypeClassifierCandidate],
        fallbackTypeID: String
    ) async throws -> String {
        _ = candidates
        let resolved = try await classify(transcript: transcript)
        let resolvedID = resolved.rawValue
        if candidates.contains(where: { $0.typeId == resolvedID }) {
            return resolvedID
        }
        return fallbackTypeID
    }
}

public extension RuntimeAwareSummarizationServicing {
    func summarizePass(
        transcriptChunk: String,
        previousSummaryJSON: String?,
        passIndex: Int,
        totalPasses: Int,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage,
        resolvedPromptBundle: ResolvedPromptBundle?
    ) async throws -> String {
        let existingStateBlock: String
        if let previousSummaryJSON,
           !previousSummaryJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            existingStateBlock = """
            Existing accepted state:
            \(previousSummaryJSON)

            """
        } else {
            existingStateBlock = ""
        }

        let transcript = """
        Process summarization pass \(passIndex) of \(totalPasses).
        Use the existing accepted state only to avoid duplicates.
        Return only net-new material from this chunk.

        Return one valid JSON object with exactly these fields:
        - title (string; empty string if unchanged)
        - date (YYYY-MM-DD; empty string if unchanged)
        - summary_points (array of short, high-signal new facts from this chunk only)
        - decisions (array of new decisions only)
        - action_items (array of objects with owner and task; new or materially refined items only)
        - open_questions (array of new open questions only)
        - key_points (array of new key points only)

        Rules:
        - Do not restate information already captured in the existing accepted state.
        - Do not rewrite the full meeting summary.
        - Use empty arrays when there is nothing new for a field.
        - Do not output markdown fences or prose outside JSON.

        \(existingStateBlock)Transcript chunk:
        \(transcriptChunk)
        """

        return try await summarize(
            transcript: transcript,
            meetingDate: meetingDate,
            meetingType: meetingType,
            languageProcessing: languageProcessing,
            outputLanguage: outputLanguage,
            resolvedPromptBundle: resolvedPromptBundle
        )
    }
}

public protocol ScreenContextInferencing: Sendable {
    func inferScreenContext(from imageData: Data, windowTitle: String) async throws -> ScreenContextInference
}

public protocol CapabilityAvailabilityProviding: Sendable {
    func availability(for capability: InferenceCapability) async throws -> CapabilityAvailabilityState
}

public enum SilenceAutoStopEvent: Sendable, Equatable {
    case warningStarted(RecordingAlert)
    case warningCanceledBySpeech
    case warningCanceledByUser
    case autoStopTriggered
    case statusChanged(SilenceStatusSnapshot)
}

public protocol SilenceAutoStopControlling: Sendable {
    func start(sessionID: UUID, startedAt: Date) async
    func stop() async
    func ingest(level: Float, at: Date) async
    func keepRecording() async
    func status() async -> SilenceStatusSnapshot
}

@MainActor
public protocol RecordingAlertNotifying: AnyObject {
    func notifySilenceStopWarning(alert: RecordingAlert) async -> Bool
    func notifySharedWindowClosed(alert: RecordingAlert) async -> Bool
    func clearSilenceStopWarning() async
    func clearSharedWindowClosedWarning() async
}

// MARK: - Models

public struct ModelDownloadProgress: Sendable, Equatable {
    /// 0...1 across all required model downloads.
    public var fractionCompleted: Double

    /// Optional human-readable label (e.g. "Downloading whisper model").
    public var label: String

    public init(fractionCompleted: Double, label: String) {
        self.fractionCompleted = fractionCompleted
        self.label = label
    }
}

public struct ModelValidationResult: Sendable, Equatable {
    public var missingModelIDs: [String]
    public var invalidModelIDs: [String]

    public var isReady: Bool {
        missingModelIDs.isEmpty && invalidModelIDs.isEmpty
    }

    public init(missingModelIDs: [String], invalidModelIDs: [String]) {
        self.missingModelIDs = missingModelIDs
        self.invalidModelIDs = invalidModelIDs
    }
}

public protocol ModelManaging: Sendable {
    func ensureModelsPresent(progress: (@Sendable (ModelDownloadProgress) -> Void)?) async throws
    func validateModels() async throws -> ModelValidationResult
    func removeModels(withIDs ids: [String]) async throws
}

public protocol VocabularyBoostingSettingsStoring: Sendable {
    func load() -> GlobalVocabularyBoostingSettings
    func save(_ settings: GlobalVocabularyBoostingSettings)
    func clear()
}

public protocol SessionVocabularyResolving: Sendable {
    func resolve(
        globalSettings: GlobalVocabularyBoostingSettings,
        sessionMode: VocabularyBoostingSessionMode,
        sessionCustomInput: String,
        readiness: VocabularyReadinessStatus
    ) -> SessionVocabularyResolution
}

public protocol MeetingTypeLibraryStoring: Sendable {
    func load() -> MeetingTypeLibrary
    func save(_ library: MeetingTypeLibrary)
    @discardableResult
    func saveValidated(_ library: MeetingTypeLibrary) throws -> MeetingTypeLibrary
    func clear()
}

public protocol ResolvedPromptBundleResolving: Sendable {
    func resolvePromptBundle(
        library: MeetingTypeLibrary,
        selection: MeetingTypeSelection,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage,
        autodetectResolvedTypeID: String?
    ) throws -> ResolvedPromptBundle
}

public protocol SummarizationCheckpointStoring: Sendable {
    func load(meetingID: String) async throws -> SummarizationRunState?
    func save(_ state: SummarizationRunState, for meetingID: String) async throws
    func clear(meetingID: String) async
}

public protocol MeetingRunGating: Sendable {
    func beginIfPossible(meetingID: String) async -> Bool
    func end(meetingID: String) async
}
