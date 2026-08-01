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
        transcriptRelativePath: String?,
        participantFrontmatter: MeetingParticipantFrontmatter? = nil,
        sectionVisibility: MeetingSummarySectionVisibility = .allEnabled
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

        if let participantFrontmatter {
            lines.append(contentsOf: YAMLFrontmatterCodec.encodeOwnedParticipantKeys(participantFrontmatter))
        }
        lines.append("tags:")
        lines.append("---")
        lines.append("")

        // Body
        lines.append("# \(title)")
        lines.append("")

        appendParticipants(extraction.participants, to: &lines)

        lines.append("## Summary")
        lines.append(StringNormalizer.normalizeParagraph(extraction.summary))
        lines.append("")

        appendTopics(extraction.topics, to: &lines)

        if sectionVisibility.decisions {
            lines.append("## Decisions")
            appendBullets(extraction.decisions, to: &lines)
            lines.append("")
        }

        if sectionVisibility.actionItems {
            lines.append("## Action Items")
            appendActionItems(extraction.actionItems, to: &lines)
            lines.append("")
        }

        if sectionVisibility.openQuestions {
            lines.append("## Open Questions")
            appendBullets(extraction.openQuestions, to: &lines)
            lines.append("")
        }

        if sectionVisibility.keyPoints {
            lines.append("## Key Points")
            appendBullets(extraction.keyPoints, to: &lines)
            lines.append("")
        }

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

    private func appendParticipants(_ participants: [MeetingParticipant], to lines: inout [String]) {
        let cleaned = participants
            .map {
                MeetingParticipant(
                    name: StringNormalizer.normalizeInline($0.name),
                    role: $0.role.map(StringNormalizer.normalizeInline)
                )
            }
            .filter { !$0.name.isEmpty }

        guard !cleaned.isEmpty else { return }

        lines.append("## Participants")
        for participant in cleaned {
            if let role = participant.role, !role.isEmpty {
                lines.append("- \(participant.name) — \(role)")
            } else {
                lines.append("- \(participant.name)")
            }
        }
        lines.append("")
    }

    private func appendTopics(_ topics: [MeetingTopic], to lines: inout [String]) {
        let cleaned = topics
            .map {
                MeetingTopic(
                    title: StringNormalizer.normalizeInline($0.title),
                    points: $0.points.map { StringNormalizer.normalizeInline($0) }.filter { !$0.isEmpty }
                )
            }
            .filter { !$0.title.isEmpty }

        guard !cleaned.isEmpty else { return }

        lines.append("## Topics Discussed")
        for (index, topic) in cleaned.enumerated() {
            lines.append("")
            lines.append("### \(index + 1). \(topic.title)")
            for point in topic.points {
                lines.append("- \(point)")
            }
        }
        lines.append("")
    }

    private func appendActionItems(_ items: [ActionItem], to lines: inout [String]) {
        let cleaned = items
            .map {
                ActionItem(
                    owner: StringNormalizer.normalizeInline($0.owner),
                    task: StringNormalizer.normalizeInline($0.task),
                    dueDate: $0.dueDate.map(StringNormalizer.normalizeInline),
                    status: $0.status.map(StringNormalizer.normalizeInline),
                    comments: $0.comments.map(StringNormalizer.normalizeInline)
                )
            }
            .filter { !$0.task.isEmpty || !$0.owner.isEmpty }

        if cleaned.isEmpty {
            return
        }

        // Table mode when any item carries table columns; legacy checkbox list otherwise.
        if cleaned.contains(where: \.hasTableFields) {
            lines.append("| # | Action | Owner | Due Date | Status | Comments |")
            lines.append("|---|--------|-------|----------|--------|----------|")
            for (index, item) in cleaned.enumerated() {
                let cells = [
                    "\(index + 1)",
                    Self.tableCell(item.task),
                    Self.tableCell(item.owner),
                    Self.tableCell(item.dueDate ?? "TBD", fallback: "TBD"),
                    Self.tableCell(item.status ?? "Not Started", fallback: "Not Started"),
                    Self.tableCell(item.comments ?? ""),
                ]
                lines.append("| " + cells.joined(separator: " | ") + " |")
            }
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

    private static func tableCell(_ value: String, fallback: String = "") -> String {
        let escaped = value.replacingOccurrences(of: "|", with: "\\|")
        let trimmed = escaped.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? fallback : trimmed
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
