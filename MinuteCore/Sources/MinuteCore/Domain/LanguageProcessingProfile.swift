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
            return "Detect transcript language and normalize interpretation toward English before extraction."
        case .autoPreserve:
            return "Detect transcript language and preserve original-language interpretation during extraction."
        }
    }

    /// Additional system instruction appended to the summarization system prompt.
    public var summarizationSystemInstruction: String {
        switch self {
        case .autoToEnglish:
            return """
            Language interpretation mode: Auto -> English.
            Determine dominant transcript language from the provided text.
            If dominant language is not English, normalize meaning to English internally before producing structured output.
            Preserve technical terms, code tokens, APIs, and proper nouns in their original form for correctness.
            """
        case .autoPreserve:
            return """
            Language interpretation mode: Auto -> Preserve.
            Determine dominant transcript language from the provided text and reason primarily in that language.
            Do not force internal translation to English unless needed to resolve ambiguous ASR fragments.
            Preserve technical terms, code tokens, APIs, and proper nouns in their original form for correctness.
            """
        }
    }

    /// Additional user instruction prepended before transcript content.
    /// This mirrors the system instruction for models that weight user instructions more heavily.
    public var summarizationUserInstruction: String {
        switch self {
        case .autoToEnglish:
            return """
            Interpretation mode for this request: normalize meaning to English when transcript is non-English.
            """
        case .autoPreserve:
            return """
            Interpretation mode for this request: keep dominant transcript language semantics.
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
