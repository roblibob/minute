import Foundation

/// Deterministically renders the transcript Markdown file stored in the vault.
///
/// The transcript is produced by Whisper and stored as plain text (not embedded into the meeting note body).
public struct TranscriptMarkdownRenderer: Sendable {
    public init() {}

    public func render(
        title: String,
        dateISO: String,
        transcript: String,
        attributedSegments: [AttributedTranscriptSegment] = [],
        screenContextEntries: [TranscriptTimelineEntry] = [],
        speakerDisplayNames: [Int: String] = [:]
    ) -> String {
        let safeTitle = FilenameSanitizer.sanitizeTitle(title)

        var lines: [String] = []
        lines.reserveCapacity(32)

        lines.append("---")
        lines.append("type: meeting_transcript")
        lines.append("date: \(dateISO)")
        lines.append("title: \(yamlDoubleQuoted(safeTitle))")
        lines.append("source: \"Minute\"")
        lines.append("---")
        lines.append("")

        lines.append("# \(safeTitle) — Transcript")
        lines.append("")

        if attributedSegments.isEmpty && screenContextEntries.isEmpty {
            let body = transcript
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !body.isEmpty {
                lines.append(body)
            }
        } else {
            let timelineEntries = makeRenderableTimelineEntries(
                attributedSegments: attributedSegments,
                screenContextEntries: screenContextEntries,
                speakerDisplayNames: speakerDisplayNames
            )

            for (index, entry) in timelineEntries.enumerated() {
                lines.append(entry.heading)
                lines.append(entry.body)
                if index < timelineEntries.count - 1 {
                    lines.append("")
                }
            }
        }

        // Ensure file ends with a newline.
        return lines.joined(separator: "\n") + "\n"
    }

    private func yamlDoubleQuoted(_ value: String) -> String {
        // YAML double-quoted string escaping.
        var escaped = value
        escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\")
        escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
        escaped = escaped.replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    private func formatTimestamp(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func makeRenderableTimelineEntries(
        attributedSegments: [AttributedTranscriptSegment],
        screenContextEntries: [TranscriptTimelineEntry],
        speakerDisplayNames: [Int: String]
    ) -> [RenderableTimelineEntry] {
        var entries: [RenderableTimelineEntry] = []
        entries.reserveCapacity(attributedSegments.count + screenContextEntries.count)
        var nextSequenceIndex = 0

        for segment in attributedSegments {
            let start = formatTimestamp(segment.startSeconds)
            let end = formatTimestamp(segment.endSeconds)
            let mappedName = speakerDisplayNames[segment.speakerId]?.trimmingCharacters(in: .whitespacesAndNewlines)
            let heading: String
            if let mappedName, !mappedName.isEmpty {
                heading = "Speaker \(segment.speakerId) (\(mappedName)) [\(start) - \(end)]"
            } else {
                heading = "Speaker \(segment.speakerId) [\(start) - \(end)]"
            }
            let body = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }
            entries.append(
                RenderableTimelineEntry(
                    timestampStartSeconds: max(0, segment.startSeconds),
                    sortIndex: 0,
                    sequenceIndex: nextSequenceIndex,
                    heading: heading,
                    body: body
                )
            )
            nextSequenceIndex += 1
        }

        for entry in screenContextEntries where entry.kind == .screenContext {
            let timestamp = formatTimestamp(entry.timestampStartSeconds)
            let windowTitle = entry.windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            let heading: String
            if let windowTitle, !windowTitle.isEmpty {
                heading = "Screen Context (\(windowTitle)) [\(timestamp)]"
            } else {
                heading = "Screen Context [\(timestamp)]"
            }
            let body = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }
            entries.append(
                RenderableTimelineEntry(
                    timestampStartSeconds: max(0, entry.timestampStartSeconds),
                    sortIndex: 1,
                    sequenceIndex: nextSequenceIndex,
                    heading: heading,
                    body: body
                )
            )
            nextSequenceIndex += 1
        }

        entries.sort {
            if $0.timestampStartSeconds == $1.timestampStartSeconds {
                if $0.sortIndex == $1.sortIndex {
                    return $0.sequenceIndex < $1.sequenceIndex
                }
                return $0.sortIndex < $1.sortIndex
            }
            return $0.timestampStartSeconds < $1.timestampStartSeconds
        }
        return entries
    }
}

private struct RenderableTimelineEntry {
    var timestampStartSeconds: Double
    var sortIndex: Int
    var sequenceIndex: Int
    var heading: String
    var body: String
}
