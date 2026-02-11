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

    /// Classifies the meeting type based on the transcript.
    func classify(
        transcript: String
    ) async throws -> MeetingType

    /// Attempts to repair invalid JSON to match the schema.
    func repairJSON(_ invalidJSON: String) async throws -> String
}

public protocol ScreenContextInferencing: Sendable {
    func inferScreenContext(from imageData: Data, windowTitle: String) async throws -> ScreenContextInference
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
