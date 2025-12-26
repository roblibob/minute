import Foundation

/// Deterministically renders the v1 meeting note Markdown.
///
/// The LLM never writes Markdown; it only produces JSON decoded into `MeetingExtraction`.
public struct MarkdownRenderer: Sendable {
    public init() {}

    public func render(
        extraction: MeetingExtraction,
        audioRelativePath: String?,
        transcriptRelativePath: String?
    ) -> String {
        let title = normalizedTitle(extraction.title)
        let date = extraction.date

        var lines: [String] = []
        lines.reserveCapacity(64)

        // YAML frontmatter (v1 contract; keep deterministic ordering).
        lines.append("---")
        lines.append("type: meeting")
        lines.append("date: \(date)")
        lines.append("title: \(yamlDoubleQuoted(title))")
        if let audioRelativePath {
            lines.append("audio: \(yamlDoubleQuoted(audioRelativePath))")
        }
        if let transcriptRelativePath {
            lines.append("transcript: \(yamlDoubleQuoted(transcriptRelativePath))")
        }
        lines.append("source: \"Minute\"")
        lines.append("---")
        lines.append("")

        // Body
        lines.append("# \(title)")
        lines.append("")

        lines.append("## Summary")
        lines.append(normalizeParagraph(extraction.summary))
        lines.append("")

        lines.append("## Decisions")
        appendBullets(extraction.decisions, to: &lines)
        lines.append("")

        lines.append("## Action Items")
        appendActionItems(extraction.actionItems, to: &lines)
        lines.append("")

        lines.append("## Open Questions")
        appendBullets(extraction.openQuestions, to: &lines)
        lines.append("")

        lines.append("## Key Points")
        appendBullets(extraction.keyPoints, to: &lines)
        lines.append("")

        if let audioRelativePath {
            lines.append("## Audio")
            lines.append("[[\(audioRelativePath)]]")
            lines.append("")
        }

        if let transcriptRelativePath {
            lines.append("## Transcript")
            lines.append("[[\(transcriptRelativePath)]]")
        }

        // Ensure file ends with a newline.
        return lines.joined(separator: "\n") + "\n"
    }

    private func appendBullets(_ items: [String], to lines: inout [String]) {
        let cleaned = items
            .map { normalizeInline($0) }
            .filter { !$0.isEmpty }

        if cleaned.isEmpty {
            // Keep the section present but empty.
            return
        }

        for item in cleaned {
            lines.append("- \(item)")
        }
    }

    private func appendActionItems(_ items: [ActionItem], to lines: inout [String]) {
        let cleaned = items
            .map { ActionItem(owner: normalizeInline($0.owner), task: normalizeInline($0.task)) }
            .filter { !$0.task.isEmpty || !$0.owner.isEmpty }

        if cleaned.isEmpty {
            return
        }

        for item in cleaned {
            if item.owner.isEmpty {
                lines.append("- [ ] \(item.task)")
            } else {
                lines.append("- [ ] \(item.task) (Owner: \(item.owner))")
            }
        }
    }

    private func yamlDoubleQuoted(_ value: String) -> String {
        // YAML double-quoted string escaping.
        var escaped = value
        escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\")
        escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
        escaped = escaped.replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    private func normalizeParagraph(_ value: String) -> String {
        // Keep paragraphs as-is but normalize line endings and trim.
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeInline(_ value: String) -> String {
        // Normalize to a single-line, trimmed string.
        normalizeParagraph(value)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedTitle(_ value: String) -> String {
        let title = normalizeInline(value)
        return title.isEmpty ? "Untitled" : title
    }
}
