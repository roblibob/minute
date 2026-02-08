import Testing
import Foundation
@testable import MinuteCore

struct MarkdownRendererParticipantFrontmatterTests {
    @Test
    func render_withParticipantFrontmatter_includesParticipantsAndSpeakerMapDeterministically() {
        let extraction = MeetingExtraction(
            title: "Weekly Sync",
            date: "2025-12-19",
            summary: "Summary.",
            decisions: [],
            actionItems: [],
            openQuestions: [],
            keyPoints: []
        )

        let frontmatter = MeetingParticipantFrontmatter(
            participants: ["Alice", "Bob"],
            speakerMap: [1: "Alice", 2: "Bob"],
            speakerOrder: [2, 1]
        )

        let markdown = MarkdownRenderer().render(
            extraction: extraction,
            noteDateTime: "2025-12-19 09:00",
            audioDurationSeconds: nil,
            audioRelativePath: nil,
            transcriptRelativePath: nil,
            participantFrontmatter: frontmatter
        )

        let expectedFrontmatter = [
            "---",
            "type: meeting",
            "date: 2025-12-19 09:00",
            "title: \"Weekly Sync\"",
            "source: \"Minute\"",
            "participants:",
            "  - \"[[Alice]]\"",
            "  - \"[[Bob]]\"",
            "speaker_map:",
            "  \"2\": \"Bob\"",
            "  \"1\": \"Alice\"",
            "speaker_order:",
            "  - 2",
            "  - 1",
            "tags:",
            "---",
            "",
            "",
        ].joined(separator: "\n")

        #expect(markdown.hasPrefix(expectedFrontmatter))
    }

    @Test
    func render_withoutParticipantFrontmatter_doesNotIncludeParticipantsOrSpeakerMap() {
        let extraction = MeetingExtraction(
            title: "Weekly Sync",
            date: "2025-12-19",
            summary: "Summary.",
            decisions: [],
            actionItems: [],
            openQuestions: [],
            keyPoints: []
        )

        let markdown = MarkdownRenderer().render(
            extraction: extraction,
            noteDateTime: "2025-12-19 09:00",
            audioDurationSeconds: nil,
            audioRelativePath: nil,
            transcriptRelativePath: nil
        )

        #expect(!markdown.contains("participants:\n"))
        #expect(!markdown.contains("speaker_map:\n"))
    }
}
