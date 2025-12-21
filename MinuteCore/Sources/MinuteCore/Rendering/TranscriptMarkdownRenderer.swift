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
        attributedSegments: [AttributedTranscriptSegment] = []
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

        if attributedSegments.isEmpty {
            let body = transcript
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !body.isEmpty {
                lines.append(body)
            }
        } else {
            for (index, segment) in attributedSegments.enumerated() {
                let start = formatTimestamp(segment.startSeconds)
                let end = formatTimestamp(segment.endSeconds)
                lines.append("Speaker \(segment.speakerId) [\(start) - \(end)]")
                lines.append(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))
                if index < attributedSegments.count - 1 {
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
}
