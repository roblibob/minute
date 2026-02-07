import Foundation

public struct MeetingSpeakerNamingService: Sendable {
    private let vaultWriter: any VaultWriting
    private let editor: MeetingFrontmatterEditor

    public init(
        vaultWriter: some VaultWriting,
        editor: MeetingFrontmatterEditor = MeetingFrontmatterEditor()
    ) {
        self.vaultWriter = vaultWriter
        self.editor = editor
    }

    public func loadOwnedParticipantFrontmatter(from noteURL: URL) throws -> MeetingParticipantFrontmatter {
        let markdown = try String(contentsOf: noteURL, encoding: .utf8)
        return loadOwnedParticipantFrontmatter(from: markdown)
    }

    public func loadOwnedParticipantFrontmatter(from markdown: String) -> MeetingParticipantFrontmatter {
        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first == "---" else {
            return MeetingParticipantFrontmatter(participants: [], speakerMap: [:])
        }
        guard let closingIndex = lines.dropFirst().firstIndex(of: "---") else {
            return MeetingParticipantFrontmatter(participants: [], speakerMap: [:])
        }

        let frontmatterLines = Array(lines[1..<closingIndex])
        return YAMLFrontmatterCodec.decodeOwnedParticipantKeys(from: frontmatterLines)
    }

    public func updateMeetingNote(
        at noteURL: URL,
        ownedFrontmatter: MeetingParticipantFrontmatter
    ) throws {
        let existing = try String(contentsOf: noteURL, encoding: .utf8)
        let updated = editor.updatingOwnedParticipantKeys(in: existing, frontmatter: ownedFrontmatter)

        guard updated != existing else { return }

        let data = Data(updated.utf8)
        try vaultWriter.writeAtomically(data: data, to: noteURL)
    }
}
