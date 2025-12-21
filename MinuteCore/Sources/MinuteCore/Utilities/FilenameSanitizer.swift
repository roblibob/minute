import Foundation

public enum FilenameSanitizer {
    /// Produces a filename-safe title component suitable for macOS paths.
    ///
    /// Notes:
    /// - This is not intended to be reversible.
    /// - This intentionally avoids allowing path traversal.
    public static func sanitizeTitle(_ rawTitle: String) -> String {
        // Normalize whitespace/newlines early.
        let trimmed = rawTitle
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return "Untitled"
        }

        // Characters that are problematic on macOS and across sync tools.
        // Also replace slashes to avoid path traversal.
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\t")

        var resultScalars: [Unicode.Scalar] = []
        resultScalars.reserveCapacity(trimmed.unicodeScalars.count)

        var lastWasSpace = false
        for scalar in trimmed.unicodeScalars {
            if forbidden.contains(scalar) || CharacterSet.controlCharacters.contains(scalar) {
                if !lastWasSpace {
                    resultScalars.append(" ")
                    lastWasSpace = true
                }
                continue
            }

            if CharacterSet.whitespaces.contains(scalar) {
                if !lastWasSpace {
                    resultScalars.append(" ")
                    lastWasSpace = true
                }
                continue
            }

            resultScalars.append(scalar)
            lastWasSpace = false
        }

        var result = String(String.UnicodeScalarView(resultScalars))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Avoid reserved path segments.
        if result == "." || result == ".." {
            result = "Untitled"
        }

        if result.isEmpty {
            result = "Untitled"
        }

        // Keep filenames reasonably short.
        if result.count > 120 {
            result = String(result.prefix(120)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result
    }
}
