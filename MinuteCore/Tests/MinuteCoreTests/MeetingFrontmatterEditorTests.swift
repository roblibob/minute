import Testing
import Foundation
@testable import MinuteCore

struct MeetingFrontmatterEditorTests {
    @Test
    func updatesOnlyOwnedKeys_andPreservesBodyAndUnrelatedKeys() {
        let input = """
        ---
        type: meeting
        date: 2026-02-07 10:00
        title: \"Hello\"
        custom_key: keep me
        participants:
          - Old Name
        speaker_map:
          \"1\": Old Name
        tags:
        ---

        # Hello

        Body stays untouched.
        """

        let updated = MeetingFrontmatterEditor().updatingOwnedParticipantKeys(
            in: input,
            frontmatter: MeetingParticipantFrontmatter(
                participants: ["Alice", "Bob"],
            speakerMap: [1: "Alice", 2: "Bob"],
            speakerOrder: [2, 1]
            )
        )

        #expect(updated.contains("custom_key: keep me\n"))
        #expect(updated.contains("participants:\n  - \"[[Alice]]\"\n  - \"[[Bob]]\"\n"))
        #expect(updated.contains("speaker_map:\n  \"2\": \"Bob\"\n  \"1\": \"Alice\"\n"))
        #expect(updated.contains("speaker_order:\n  - 2\n  - 1\n"))
        #expect(updated.contains("# Hello\n\nBody stays untouched.\n"))
        #expect(!updated.contains("Old Name"))
    }

    @Test
    func whenOwnedKeysEmpty_removesExistingOwnedKeys() {
        let input = """
        ---
        type: meeting
        participants:
          - Someone
        speaker_map:
          \"1\": Someone
        speaker_order:
          - 1
        tags:
        ---

        # Title
        """

        let updated = MeetingFrontmatterEditor().updatingOwnedParticipantKeys(
            in: input,
            frontmatter: MeetingParticipantFrontmatter(participants: [], speakerMap: [:])
        )

        #expect(!updated.contains("participants:"))
        #expect(!updated.contains("speaker_map:"))
        #expect(!updated.contains("speaker_order:"))
        #expect(updated.contains("type: meeting\n"))
        #expect(updated.contains("# Title\n"))
    }
}
