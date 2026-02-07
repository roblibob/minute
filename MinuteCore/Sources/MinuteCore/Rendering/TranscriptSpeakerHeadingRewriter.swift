import Foundation

/// Rewrites only Minute-formatted transcript speaker headings.
///
/// This is intended for an explicit user action: it does not regenerate transcript content,
/// it only replaces the leading `Speaker N` token when the line matches Minute's heading format.
public enum TranscriptSpeakerHeadingRewriter {
    public static func rewrite(
        transcriptMarkdown: String,
        speakerDisplayNames: [Int: String],
        priorSpeakerDisplayNames: [Int: String] = [:]
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
            let rewritten = rewriteLineIfHeading(
                line,
                speakerDisplayNames: speakerDisplayNames,
                priorSpeakerDisplayNames: priorSpeakerDisplayNames
            )
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
        speakerDisplayNames: [Int: String],
        priorSpeakerDisplayNames: [Int: String]
    ) -> String {
        let leadingWhitespace = line.prefix { $0.isWhitespace }
        let remainder = line.dropFirst(leadingWhitespace.count)
        let trimmed = remainder.trimmingCharacters(in: .whitespaces)

        // Headings must contain the timestamp delimiter.
        guard let bracketRange = trimmed.range(of: " [") else { return line }
        let suffix = String(trimmed[bracketRange.lowerBound...])

        // Canonical heading: "Speaker <digits> ... ["
        if trimmed.hasPrefix("Speaker ") {
            let afterPrefix = trimmed.dropFirst("Speaker ".count)
            let digits = afterPrefix.prefix { $0.isNumber }
            guard let id = Int(digits) else { return line }

            guard let nameRaw = speakerDisplayNames[id] else { return line }
            let name = nameRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return line }

            // Always preserve the stable speaker id in the output.
            return String(leadingWhitespace) + "Speaker \(id) (\(name))" + suffix
        }

        // Legacy heading (from older behavior): "<Name> [".
        // If we know which speaker id that name belonged to, migrate to the canonical format.
        for (id, priorNameRaw) in priorSpeakerDisplayNames {
            let priorName = priorNameRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !priorName.isEmpty else { continue }
            guard trimmed.hasPrefix("\(priorName)") else { continue }

            guard let newNameRaw = speakerDisplayNames[id] else { continue }
            let newName = newNameRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newName.isEmpty else { continue }

            return String(leadingWhitespace) + "Speaker \(id) (\(newName))" + suffix
        }

        return line
    }
}
