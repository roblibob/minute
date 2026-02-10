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
            return "Detect input language from transcription; always write outputs in English."
        case .autoPreserve:
            return "Detect input language from transcription; write outputs in that same language."
        }
    }

    /// Additional system instruction appended to the summarization system prompt.
    public var summarizationSystemInstruction: String {
        switch self {
        case .autoToEnglish:
            return """
            Language output mode: Auto -> English.
            Use the transcription text to determine dominant language for interpretation, but ALWAYS write all user-visible fields (including title, summary, action items, and sections) in English. This requirement overrides conflicting language instructions elsewhere in the prompt.
            Preserve technical terms, code tokens, APIs, and proper nouns in their original form.
            """
        case .autoPreserve:
            return """
            Language output mode: Auto -> Preserve.
            Determine the dominant language from the transcription text and write all user-visible fields (including title, summary, action items, and sections) in that same language. Do not translate to English unless the transcription is predominantly English.
            Preserve technical terms, code tokens, APIs, and proper nouns in their original form.
            """
        }
    }

    public static func resolved(from rawValue: String?) -> LanguageProcessingProfile {
        guard let rawValue, let value = LanguageProcessingProfile(rawValue: rawValue) else {
            return AppConfiguration.Defaults.defaultStageLanguageProcessing
        }
        return value
    }
}
