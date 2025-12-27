import Foundation

/// Domain-level errors surfaced to the UI.
///
/// Keep user-visible messages concise; include debug details only in logs or optional debug UI.
public enum MinuteError: Error, LocalizedError, Sendable {
    case permissionDenied
    case screenRecordingPermissionDenied
    case screenCaptureUnavailable
    case vaultUnavailable
    case audioExportFailed
    case ffmpegMissing

    case whisperMissing
    case whisperFailed(exitCode: Int32, output: String)
    case whisperTimeout

    case llamaMissing
    case llamaFailed(exitCode: Int32, output: String)

    case modelMissing
    case mmprojMissing
    case modelChecksumMismatch
    case modelDownloadFailed(underlyingDescription: String)

    case jsonInvalid
    case vaultWriteFailed

    case llamaMTMDMissing
    case llamaMTMDFailed(exitCode: Int32, output: String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required to record audio."
        case .screenRecordingPermissionDenied:
            return "Screen recording permission is required to capture system audio."
        case .screenCaptureUnavailable:
            return "Unable to access available screen content."
        case .vaultUnavailable:
            return "The selected Obsidian vault is not available."
        case .audioExportFailed:
            return "Failed to export audio in the required format."
        case .ffmpegMissing:
            return "Audio conversion component is missing."

        case .whisperMissing:
            return "Transcription component is missing."
        case .whisperFailed:
            return "Transcription failed."
        case .whisperTimeout:
            return "Transcription timed out."

        case .llamaMissing:
            return "Summarization component is missing."
        case .llamaFailed:
            return "Summarization failed."

        case .modelMissing:
            return "Required model files are missing."
        case .mmprojMissing:
            return "Required multimodal projector is missing."
        case .modelChecksumMismatch:
            return "Downloaded model file failed verification."
        case .modelDownloadFailed:
            return "Failed to download required models."

        case .jsonInvalid:
            return "Failed to structure the meeting note."
        case .vaultWriteFailed:
            return "Failed to write meeting files to the vault."
        case .llamaMTMDMissing:
            return "Multimodal inference component is missing."
        case .llamaMTMDFailed:
            return "Multimodal inference failed."
        }
    }

    public var debugSummary: String {
        switch self {
        case .whisperFailed(let exitCode, let output):
            return "whisper failed (exitCode=\(exitCode))\n\(output)"
        case .whisperMissing:
            return "whisper missing: ensure the Whisper XPC service is embedded and signed with the app."
        case .llamaFailed(let exitCode, let output):
            return "llama failed (exitCode=\(exitCode))\n\(output)"
        case .modelDownloadFailed(let underlyingDescription):
            return "model download failed\n\(underlyingDescription)"
        case .ffmpegMissing:
            return "ffmpeg missing: ensure the ffmpeg binary is bundled with the app."
        case .mmprojMissing:
            return "mmproj missing: ensure the multimodal projector file is downloaded."
        case .llamaMTMDMissing:
            return "llama-mtmd-cli missing: ensure the CLI binary is bundled with the app."
        case .llamaMTMDFailed(let exitCode, let output):
            return "llama-mtmd-cli failed (exitCode=\(exitCode))\n\(output)"
        default:
            return String(describing: self)
        }
    }
}
