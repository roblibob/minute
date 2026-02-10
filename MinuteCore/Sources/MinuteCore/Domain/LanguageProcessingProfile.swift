import Foundation

public enum LanguageProcessingProfile: String, CaseIterable, Codable, Sendable, Identifiable {
    case autoToEnglish
    case autoPreserve

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .autoToEnglish:
            return "Auto → English"
        case .autoPreserve:
            return "Auto → Preserve"
        }
    }

    public var detailText: String {
        switch self {
        case .autoToEnglish:
            return "Detect input language; write outputs in English."
        case .autoPreserve:
            return "Detect input language; write outputs in the same language as the transcript."
        }
    }

    /// Additional system instruction appended to the summarization system prompt.
    public var summarizationSystemInstruction: String {
        switch self {
        case .autoToEnglish:
            return "Write all user-visible fields (including title, summary, action items, and sections) in English."
        case .autoPreserve:
            return "Write all user-visible fields (including title, summary, action items, and sections) in the same language as the transcript."
        }
    }

    public static func resolved(from rawValue: String?) -> LanguageProcessingProfile {
        guard let rawValue, let value = LanguageProcessingProfile(rawValue: rawValue) else {
            return AppConfiguration.Defaults.defaultStageLanguageProcessing
        }
        return value
    }
}
