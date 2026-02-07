import Foundation

public struct MeetingFrontmatterEditor: Sendable {
    public init() {}

    /// Updates only the YAML frontmatter keys owned by Minute for speaker naming.
    ///
    /// - Preserves: all other frontmatter keys and the entire markdown body.
    /// - Replaces: `participants`, `speaker_map`, and `speaker_order` blocks (if present).
    public func updatingOwnedParticipantKeys(
        in markdown: String,
        frontmatter: MeetingParticipantFrontmatter
    ) -> String {
        let normalized = normalizeNewlines(markdown)
        let lines = splitLinesPreservingEmpties(normalized)

        guard lines.first == "---" else {
            // No frontmatter: create one and keep body as-is.
            return insertFrontmatter(intoBody: normalized, owned: frontmatter)
        }

        guard let closingIndex = lines.dropFirst().firstIndex(of: "---") else {
            // Malformed frontmatter; don't risk editing.
            return normalized
        }

        let frontmatterLines = Array(lines[1..<closingIndex])
        let bodyLines = Array(lines[(closingIndex + 1)...])

        var retained = frontmatterLines
        retained = removingTopLevelKey("participants", from: retained)
        retained = removingTopLevelKey("speaker_map", from: retained)
        retained = removingTopLevelKey("speaker_order", from: retained)

        let ownedLines = YAMLFrontmatterCodec.encodeOwnedParticipantKeys(frontmatter)

        var output: [String] = []
        output.reserveCapacity(lines.count + ownedLines.count + 4)

        output.append("---")
        output.append(contentsOf: retained)
        if !ownedLines.isEmpty {
            if !retained.isEmpty {
                // Keep stable separation; no blank line required by YAML, but acceptable.
            }
            output.append(contentsOf: ownedLines)
        }
        output.append("---")
        output.append(contentsOf: bodyLines)

        return ensureTrailingNewline(output.joined(separator: "\n"))
    }

    private func insertFrontmatter(intoBody body: String, owned: MeetingParticipantFrontmatter) -> String {
        let ownedLines = YAMLFrontmatterCodec.encodeOwnedParticipantKeys(owned)
        guard !ownedLines.isEmpty else { return body }

        var output: [String] = []
        output.reserveCapacity(ownedLines.count + 4)

        output.append("---")
        output.append(contentsOf: ownedLines)
        output.append("---")

        let normalizedBody = normalizeNewlines(body)
        let bodyLines = splitLinesPreservingEmpties(normalizedBody)
        output.append(contentsOf: bodyLines)

        return ensureTrailingNewline(output.joined(separator: "\n"))
    }

    private func ensureTrailingNewline(_ text: String) -> String {
        if text.hasSuffix("\n") { return text }
        return text + "\n"
    }

    private func removingTopLevelKey(_ key: String, from frontmatterLines: [String]) -> [String] {
        var result: [String] = []
        result.reserveCapacity(frontmatterLines.count)

        var skipping = false
        for line in frontmatterLines {
            if skipping {
                if line.isEmpty || line.first == " " || line.first == "\t" {
                    continue
                }
                skipping = false
            }

            if line == "\(key):" {
                skipping = true
                continue
            }

            result.append(line)
        }

        return result
    }

    private func normalizeNewlines(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private func splitLinesPreservingEmpties(_ text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }
}
