import Foundation

/// Rewrites only Minute-formatted transcript speaker headings.
///
/// This is intended for an explicit user action: it does not regenerate transcript content,
/// it only replaces the leading `Speaker N` token when the line matches Minute's heading format.
public enum TranscriptSpeakerHeadingRewriter {
    public static func rewrite(
        transcriptMarkdown: String,
        speakerDisplayNames: [Int: String]
    ) -> String {
        let hasTrailingNewline = transcriptMarkdown.hasSuffix("\n")
        let normalized = transcriptMarkdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        var out: [String] = []
        out.reserveCapacity(lines.count)
        var didChange = false

        for lineSub in lines {
            let line = String(lineSub)
            let rewritten = rewriteLineIfHeading(line, speakerDisplayNames: speakerDisplayNames)
            if rewritten != line {
                didChange = true
            }
            out.append(rewritten)
        }

        // Preserve the original content exactly when nothing changes.
        // This avoids normalizing line endings unless a heading token is actually rewritten.
        if !didChange {
            return transcriptMarkdown
        }

        let joined = out.joined(separator: "\n")
        if hasTrailingNewline {
            return joined.hasSuffix("\n") ? joined : joined + "\n"
        }
        return joined
    }

    private static func rewriteLineIfHeading(
        _ line: String,
        speakerDisplayNames: [Int: String]
    ) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("Speaker ") else { return line }

        // Match: "Speaker <digits> ["
        let afterPrefix = trimmed.dropFirst("Speaker ".count)
        let digits = afterPrefix.prefix { $0.isNumber }
        guard let id = Int(digits) else { return line }

        let remainder = afterPrefix.dropFirst(digits.count)
        guard remainder.hasPrefix(" [") else { return line }

        guard let nameRaw = speakerDisplayNames[id] else { return line }
        let name = nameRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return line }

        // Replace only the first occurrence of "Speaker <id>" in the original line.
        guard let range = line.range(of: "Speaker \(id)") else { return line }
        return line.replacingCharacters(in: range, with: name)
    }
}
