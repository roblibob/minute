import Foundation

public enum StringNormalizer {
    /// Normalizes paragraph text, preserving line breaks but normalizing line endings and trimming.
    public static func normalizeParagraph(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Normalizes to a single-line, trimmed string.
    public static func normalizeInline(_ value: String) -> String {
        normalizeParagraph(value)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Normalizes a title, ensuring it is never empty.
    public static func normalizeTitle(_ value: String) -> String {
        let title = normalizeInline(value)
        return title.isEmpty ? "Untitled" : title
    }

    /// Escapes a string for YAML double-quoted context.
    public static func yamlDoubleQuoted(_ value: String) -> String {
        var escaped = value
        escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\")
        escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
        escaped = escaped.replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}
