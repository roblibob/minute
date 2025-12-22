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

    /// Stops recording and returns a contract-compliant WAV file URL and its duration.
    func stopRecording() async throws -> AudioCaptureResult

    /// Converts a temporary capture file to a contract-compliant WAV.
    func convertToContractWav(inputURL: URL, outputURL: URL) async throws
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

// MARK: - Transcription + Summarization

public protocol TranscriptionServicing: Sendable {
    func transcribe(wavURL: URL) async throws -> TranscriptionResult
}

public protocol DiarizationServicing: Sendable {
    func diarize(wavURL: URL) async throws -> [SpeakerSegment]
}

public protocol SummarizationServicing: Sendable {
    /// Returns raw JSON produced by the model.
    func summarize(transcript: String, meetingDate: Date) async throws -> String

    /// Attempts to repair invalid JSON to match the schema.
    func repairJSON(_ invalidJSON: String) async throws -> String
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
