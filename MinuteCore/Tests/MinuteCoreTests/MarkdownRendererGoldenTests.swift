import XCTest
@testable import MinuteCore

final class MarkdownRendererGoldenTests: XCTestCase {
    func testRender_matchesTemplateExactly() {
        let extraction = MeetingExtraction(
            title: "Weekly Sync",
            date: "2025-12-19",
            summary: "We aligned on next steps.",
            decisions: ["Ship v1"],
            actionItems: [ActionItem(owner: "Alex", task: "Draft release notes")],
            openQuestions: ["Do we need ffmpeg?"],
            keyPoints: ["Local-only processing"]
        )

        let audio = "Meetings/_audio/2025-12-19 - Weekly Sync.wav"
        let transcript = "Meetings/_transcripts/2025-12-19 - Weekly Sync.md"
        let markdown = MarkdownRenderer().render(
            extraction: extraction,
            audioRelativePath: audio,
            transcriptRelativePath: transcript
        )

        let expected = """
        ---
        type: meeting
        date: 2025-12-19
        title: \"Weekly Sync\"
        audio: \"Meetings/_audio/2025-12-19 - Weekly Sync.wav\"
        transcript: \"Meetings/_transcripts/2025-12-19 - Weekly Sync.md\"
        source: \"Minute\"
        ---

        # Weekly Sync

        ## Summary
        We aligned on next steps.

        ## Decisions
        - Ship v1

        ## Action Items
        - [ ] Draft release notes (Owner: Alex)

        ## Open Questions
        - Do we need ffmpeg?

        ## Key Points
        - Local-only processing

        ## Audio
        [[Meetings/_audio/2025-12-19 - Weekly Sync.wav]]

        ## Transcript
        [[Meetings/_transcripts/2025-12-19 - Weekly Sync.md]]
        """ + "\n"

        XCTAssertEqual(markdown, expected)
    }
}
