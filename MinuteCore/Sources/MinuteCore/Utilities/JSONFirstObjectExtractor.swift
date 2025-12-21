import Foundation

/// Extracts the first top-level JSON object from a string.
///
/// This is used as a best-effort sanitizer for local LLM output where logs or whitespace
/// may be present around an otherwise-valid JSON object.
public enum JSONFirstObjectExtractor {
    public struct Result: Sendable, Equatable {
        /// The extracted JSON object, including the outer `{}`.
        public var jsonObject: String

        /// Whether the original text contained non-whitespace outside the extracted JSON object.
        public var hasNonWhitespaceOutsideObject: Bool

        public init(jsonObject: String, hasNonWhitespaceOutsideObject: Bool) {
            self.jsonObject = jsonObject
            self.hasNonWhitespaceOutsideObject = hasNonWhitespaceOutsideObject
        }
    }

    /// Returns the first balanced JSON object found in `text`, or `nil` if none exists.
    ///
    /// - Important: This does *not* validate JSON syntax beyond balancing braces while respecting
    ///   quoted strings; JSON decoding/validation happens later.
    public static func extractFirstJSONObject(from text: String) -> Result? {
        guard let start = text.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var isEscaped = false

        var end: String.Index? = nil

        var i = start
        while i < text.endIndex {
            let ch = text[i]

            if inString {
                if isEscaped {
                    isEscaped = false
                } else if ch == "\\" {
                    isEscaped = true
                } else if ch == "\"" {
                    inString = false
                }
            } else {
                if ch == "\"" {
                    inString = true
                } else if ch == "{" {
                    depth += 1
                } else if ch == "}" {
                    depth -= 1
                    if depth == 0 {
                        end = i
                        break
                    }
                }
            }

            i = text.index(after: i)
        }

        guard let end else { return nil }

        let json = String(text[start...end])

        let prefix = text[..<start]
        let suffixStart = text.index(after: end)
        let suffix = suffixStart <= text.endIndex ? text[suffixStart...] : ""

        let outside = String(prefix) + String(suffix)
        let hasNonWhitespaceOutside = outside.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false

        return Result(jsonObject: json, hasNonWhitespaceOutsideObject: hasNonWhitespaceOutside)
    }
}
