import Foundation
import MinuteCore
import os

struct DefaultVaultWriter: VaultWriting {
    func writeAtomically(data: Data, to destinationURL: URL) throws {
        try ensureDirectoryExists(destinationURL.deletingLastPathComponent())
        try data.write(to: destinationURL, options: [.atomic])
    }

    func ensureDirectoryExists(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

// MARK: - Mocks (used until tasks 04–09 replace them)

@preconcurrency
final class MockAudioService: AudioServicing, AudioLevelMetering, @unchecked Sendable {
    private var isRecording = false

    func startRecording() async throws {
        isRecording = true
    }

    func stopRecording() async throws -> AudioCaptureResult {
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

    func convertToContractWav(inputURL: URL, outputURL: URL) async throws {
        // Placeholder: just copy bytes.
        let data = try Data(contentsOf: inputURL)
        try data.write(to: outputURL, options: [.atomic])
    }

    func setLevelHandler(_ handler: (@Sendable (Float) -> Void)?) async {
        _ = handler
    }
}

struct MockTranscriptionService: TranscriptionServicing {
    func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        try await Task.sleep(nanoseconds: 800_000_000)
        return TranscriptionResult(
            text: "[mock transcript] file=\(wavURL.lastPathComponent)",
            segments: []
        )
    }
}

struct MockMediaImportService: MediaImporting {
    func importMedia(from sourceURL: URL) async throws -> MediaImportResult {
        _ = sourceURL
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-import-\(UUID().uuidString).wav")
        try Data().write(to: url, options: [.atomic])
        return MediaImportResult(wavURL: url, duration: 0, suggestedStartDate: Date())
    }
}

struct MockDiarizationService: DiarizationServicing {
    func diarize(wavURL: URL) async throws -> [SpeakerSegment] {
        _ = wavURL
        return []
    }
}

/// Used by the live pipeline when the whisper executable is not yet bundled / configured.
struct MissingTranscriptionService: TranscriptionServicing {
    func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        throw MinuteError.whisperMissing
    }
}

/// Used by the live pipeline when the llama executable is not yet bundled / configured.
struct MissingSummarizationService: SummarizationServicing {
    func summarize(
        transcript: String,
        meetingDate: Date,
        screenContext: ScreenContextSummary?
    ) async throws -> String {
        _ = transcript
        _ = meetingDate
        _ = screenContext
        throw MinuteError.llamaMissing
    }

    func repairJSON(_ invalidJSON: String) async throws -> String {
        throw MinuteError.llamaMissing
    }
}

struct MockSummarizationService: SummarizationServicing {
    func summarize(
        transcript: String,
        meetingDate: Date,
        screenContext: ScreenContextSummary?
    ) async throws -> String {
        try await Task.sleep(nanoseconds: 800_000_000)

        // Do NOT include the transcript in outputs.
        _ = transcript
        _ = screenContext
        let iso = MinuteISODate.format(meetingDate)
        let title = "Meeting \(iso)"

        return """
        {
          \"title\": \"\(title)\",
          \"date\": \"\(iso)\",
          \"summary\": \"Mock summary.\",
          \"decisions\": [\"Mock decision\"],
          \"action_items\": [{\"owner\": \"\", \"task\": \"Mock action\", \"due\": \"\"}],
          \"open_questions\": [\"Mock question\"],
          \"key_points\": [\"Mock key point\"]
        }
        """
    }

    func repairJSON(_ invalidJSON: String) async throws -> String {
        // Naive repair: return original. Task 07 will implement real validation/repair behavior.
        try await Task.sleep(nanoseconds: 200_000_000)
        return invalidJSON
    }
}

struct MockModelManager: ModelManaging {
    func ensureModelsPresent(progress: (@Sendable (ModelDownloadProgress) -> Void)?) async throws {
        // No-op for now.
        _ = progress
    }

    func validateModels() async throws -> ModelValidationResult {
        ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])
    }

    func removeModels(withIDs ids: [String]) async throws {
        _ = ids
    }
}

// MARK: - Utilities

enum MinuteISODate {
    nonisolated static func format(_ date: Date, calendar: Calendar = .current) -> String {
        MeetingFileContract.isoDate(date, calendar: calendar)
    }

    nonisolated static func parse(_ value: String, calendar: Calendar = .current) -> Date? {
        let parts = value.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let d = Int(parts[2])
        else {
            return nil
        }

        var cal = calendar
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone

        var components = DateComponents()
        components.calendar = cal
        components.timeZone = cal.timeZone
        components.year = y
        components.month = m
        components.day = d
        components.hour = 0
        components.minute = 0
        components.second = 0

        return cal.date(from: components)
    }
}
