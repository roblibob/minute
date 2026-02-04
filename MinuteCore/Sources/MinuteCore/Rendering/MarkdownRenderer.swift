import Foundation

/// Deterministically renders the v1 meeting note Markdown.
///
/// The LLM never writes Markdown; it only produces JSON decoded into `MeetingExtraction`.
public struct MarkdownRenderer: Sendable {
    public init() {}

    public func render(
        extraction: MeetingExtraction,
        noteDateTime: String,
        audioDurationSeconds: TimeInterval?,
        audioRelativePath: String?,
        transcriptRelativePath: String?
    ) -> String {
        let title = StringNormalizer.normalizeTitle(extraction.title)
        let date = noteDateTime
        let length = Self.formatDuration(audioDurationSeconds)

        var lines: [String] = []
        lines.reserveCapacity(64)

        // YAML frontmatter (v1 contract; keep deterministic ordering).
        lines.append("---")
        lines.append("type: meeting")
        lines.append("date: \(date)")
        lines.append("title: \(StringNormalizer.yamlDoubleQuoted(title))")
        lines.append("source: \"Minute\"")
        if let type = extraction.meetingType {
            lines.append("meeting_type: \(type.rawValue)")
        }
        if let length {
            lines.append("length: \(length)")
        }
        lines.append("tags:")
        lines.append("---")
        lines.append("")

        // Body
        lines.append("# \(title)")
        lines.append("")

        lines.append("## Summary")
        lines.append(StringNormalizer.normalizeParagraph(extraction.summary))
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
            .map { StringNormalizer.normalizeInline($0) }
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
            .map {
                ActionItem(
                    owner: StringNormalizer.normalizeInline($0.owner),
                    task: StringNormalizer.normalizeInline($0.task)
                )
            }
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

    private static func formatDuration(_ seconds: TimeInterval?) -> String? {
        guard let seconds, seconds > 0 else { return nil }
        let totalMinutes = max(1, Int((seconds / 60.0).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            if minutes == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(minutes)m"
        }
        return "\(totalMinutes)m"
    }

}
