import Foundation

public enum TranscriptionBackend: String, CaseIterable, Sendable, Identifiable {
    case whisper
    case fluidAudio

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .whisper:
            return "Whisper"
        case .fluidAudio:
            return "FluidAudio"
        }
    }

    public var summary: String {
        switch self {
        case .whisper:
            return "Local transcription via whisper.cpp."
        case .fluidAudio:
            return "Local transcription via Parakeet ASR."
        }
    }

    public static func backend(for id: String?) -> TranscriptionBackend {
        guard let id, let backend = TranscriptionBackend(rawValue: id) else {
            return .whisper
        }
        return backend
    }

    public static func displayName(for id: String) -> String {
        backend(for: id).displayName
    }
}
