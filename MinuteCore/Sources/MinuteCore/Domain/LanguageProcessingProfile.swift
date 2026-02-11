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
            MANDATORY RULE: Use the transcription text to determine dominant language for interpretation, but ALWAYS write all user-visible JSON values (including title, summary, decisions, action items, open questions, and key points) in English.
            This requirement overrides conflicting language instructions elsewhere in the prompt.
            Preserve technical terms, code tokens, APIs, and proper nouns in their original form.
            """
        case .autoPreserve:
            return """
            Language output mode: Auto -> Preserve.
            MANDATORY RULE: Determine the dominant language from the transcription text and write all user-visible JSON values (including title, summary, decisions, action items, open questions, and key points) in that same language.
            Do not translate to English unless the transcription is predominantly English.
            Preserve technical terms, code tokens, APIs, and proper nouns in their original form.
            """
        }
    }

    /// Additional user instruction prepended before transcript content.
    /// This mirrors the system instruction for models that weight user instructions more heavily.
    public var summarizationUserInstruction: String {
        switch self {
        case .autoToEnglish:
            return """
            Language constraint for this request: Output all JSON string values in English.
            """
        case .autoPreserve:
            return """
            Language constraint for this request: Detect the dominant transcript language and keep all JSON string values in that same language.
            If the dominant language is not English, do not translate the output to English.
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
