import Testing
import Foundation
@testable import MinuteCore

struct MeetingSpeakerNamingPersistenceTests {
    @Test
    func updateMeetingNote_updatesOnlyOwnedKeys_andPreservesBodyExactly() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-speaker-naming-persistence-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let noteURL = tempDir.appendingPathComponent("note.md")
        let original = """
        ---
        type: meeting
        custom_key: keep me
        participants:
          - Someone
        speaker_map:
          \"1\": Someone
        tags:
          - foo
        ---

        # Title

        Body line 1
        Body line 2
        """
        try Data(original.utf8).write(to: noteURL, options: [.atomic])

        let service = MeetingSpeakerNamingService(vaultWriter: SpyVaultWriter())

        let owned = MeetingParticipantFrontmatter(
            participants: ["Alice", "Bob"],
            speakerMap: [1: "Alice", 2: "Bob"],
            speakerOrder: [2, 1]
        )

        try service.updateMeetingNote(at: noteURL, ownedFrontmatter: owned)
        let updated = try String(contentsOf: noteURL, encoding: .utf8)

        #expect(updated.contains("custom_key: keep me\n"))
        #expect(updated.contains("participants:\n  - \"[[Alice]]\"\n  - \"[[Bob]]\"\n"))
        #expect(updated.contains("speaker_map:\n  \"2\": \"Bob\"\n  \"1\": \"Alice\"\n"))
        #expect(updated.contains("speaker_order:\n  - 2\n  - 1\n"))

        let expectedBody = """
        # Title

        Body line 1
        Body line 2
        """ + "\n"

        let body = updated.components(separatedBy: "---\n\n").last
        #expect(body == expectedBody)
    }
}

private final class SpyVaultWriter: VaultWriting, @unchecked Sendable {
    func writeAtomically(data: Data, to destinationURL: URL) throws {
    try ensureDirectoryExists(destinationURL.deletingLastPathComponent())
        try data.write(to: destinationURL, options: [.atomic])
    }

  func ensureDirectoryExists(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  }
}
