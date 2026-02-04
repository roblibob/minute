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

// MARK: - Mocks (used until tasks 04–09 replace them)

@preconcurrency
public final class MockAudioService: AudioServicing, AudioLevelMetering, AudioCaptureControlling, @unchecked Sendable {
    private var isRecording = false
    private var microphoneEnabled = true
    private var systemAudioEnabled = true

    public init() {}

    public func startRecording() async throws {
        isRecording = true
    }

    public func stopRecording() async throws -> AudioCaptureResult {
        guard isRecording else {
            // For now treat as generic failure.
            throw MinuteError.audioExportFailed
        }

        isRecording = false

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-capture-\(UUID().uuidString).wav")

        // Placeholder data.
        try Data().write(to: url, options: [.atomic])
        return AudioCaptureResult(wavURL: url, duration: 0)
    }

    public func convertToContractWav(inputURL: URL, outputURL: URL) async throws {
        // Placeholder: just copy bytes.
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
    public func diarize(wavURL: URL) async throws -> [SpeakerSegment] {
        _ = wavURL
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
    public func summarize(transcript: String, meetingDate: Date) async throws -> String {
        _ = transcript
        _ = meetingDate
        throw MinuteError.llamaMissing
    }

    public func repairJSON(_ invalidJSON: String) async throws -> String {
        throw MinuteError.llamaMissing
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

public struct MockScreenContextInferenceService: ScreenContextInferencing {
    public init() {}
    public func inferScreenContext(from imageData: Data, windowTitle: String) async throws -> ScreenContextInference {
        _ = imageData
        return ScreenContextInference(text: "Mock screen context from \(windowTitle).")
    }
}

public struct MockSummarizationService: SummarizationServicing {
    public init() {}
    public func summarize(transcript: String, meetingDate: Date) async throws -> String {
        try await Task.sleep(nanoseconds: 800_000_000)

        // Do NOT include the transcript in outputs.
        _ = transcript
        let iso = MinuteISODate.format(meetingDate)
        let title = "Meeting \(iso)"

        return """
        {
          \"title\": \"\(title)\",
          \"date\": \"\(iso)\",
          \"summary\": \"Mock summary.\",
          \"decisions\": [\"Mock decision\"],
          \"action_items\": [{\"owner\": \"\", \"task\": \"Mock action\"}],
          \"open_questions\": [\"Mock question\"],
          \"key_points\": [\"Mock key point\"]
        }
        """
    }

    public func repairJSON(_ invalidJSON: String) async throws -> String {
        // Naive repair: return original. Task 07 will implement real validation/repair behavior.
        try await Task.sleep(nanoseconds: 200_000_000)
        return invalidJSON
    }
}

public struct MockModelManager: ModelManaging {
    public init() {}
    public func ensureModelsPresent(progress: (@Sendable (ModelDownloadProgress) -> Void)?) async throws {
        // No-op for now.
        _ = progress
    }

    public func validateModels() async throws -> ModelValidationResult {
        ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])
    }

    public func removeModels(withIDs ids: [String]) async throws {
        _ = ids
    }
}
