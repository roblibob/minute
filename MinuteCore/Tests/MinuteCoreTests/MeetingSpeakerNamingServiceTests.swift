import Testing
import Foundation
@testable import MinuteCore

struct MeetingSpeakerNamingServiceTests {
    @Test
    func updateMeetingNote_writesAtomically_andIsIdempotent() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-speaker-naming-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let noteURL = tempDir.appendingPathComponent("note.md")
        let input = """
        ---
        type: meeting
        custom_key: keep me
        participants:
          - Someone
        speaker_map:
          \"1\": Someone
        tags:
        ---

        # Title
        """
        try Data(input.utf8).write(to: noteURL, options: [.atomic])

        let writer = SpyVaultWriter()
        let service = MeetingSpeakerNamingService(vaultWriter: writer)

        let owned = MeetingParticipantFrontmatter(
            participants: ["Alice", "Bob"],
            speakerMap: [1: "Alice", 2: "Bob"],
            speakerOrder: [2, 1]
        )

        try service.updateMeetingNote(at: noteURL, ownedFrontmatter: owned)
        let afterFirst = try String(contentsOf: noteURL, encoding: .utf8)

        #expect(writer.writeCalls.count == 1)
        #expect(afterFirst.contains("custom_key: keep me\n"))
        #expect(afterFirst.contains("participants:\n  - \"[[Alice]]\"\n  - \"[[Bob]]\"\n"))
        #expect(afterFirst.contains("speaker_map:\n  \"2\": \"Bob\"\n  \"1\": \"Alice\"\n"))
        #expect(afterFirst.contains("speaker_order:\n  - 2\n  - 1\n"))

        // Second call should be a no-op (deterministic + avoids unnecessary writes).
        try service.updateMeetingNote(at: noteURL, ownedFrontmatter: owned)
        let afterSecond = try String(contentsOf: noteURL, encoding: .utf8)

        #expect(writer.writeCalls.count == 1)
        #expect(afterSecond == afterFirst)
    }

    @Test
    func loadOwnedParticipantFrontmatter_parsesParticipantsAndSpeakerMap() throws {
                let input = """
                ---
                type: meeting
                participants:
                    - "[[Alice]]"
                    - "[[Bob]]"
                speaker_map:
                    \"1\": Alice
                    \"2\": Bob
                speaker_order:
                    - 2
                    - 1
                tags:
                ---

                # Title
                """

        let service = MeetingSpeakerNamingService(vaultWriter: SpyVaultWriter())
        let parsed = service.loadOwnedParticipantFrontmatter(from: input)

        #expect(parsed.participants == ["Alice", "Bob"])
        #expect(parsed.speakerMap[1] == "Alice")
        #expect(parsed.speakerMap[2] == "Bob")
        #expect(parsed.speakerOrder == [2, 1])
    }
}

private final class SpyVaultWriter: VaultWriting, @unchecked Sendable {
    struct Call: Equatable {
        var data: Data
        var destinationURL: URL
    }

    private(set) var writeCalls: [Call] = []

    func writeAtomically(data: Data, to destinationURL: URL) throws {
        writeCalls.append(Call(data: data, destinationURL: destinationURL))
        try ensureDirectoryExists(destinationURL.deletingLastPathComponent())
        try data.write(to: destinationURL, options: [.atomic])
    }

    func ensureDirectoryExists(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
