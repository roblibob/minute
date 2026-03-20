import Foundation
import Testing
@testable import MinuteCore

struct TranscriptMarkdownRendererScreenContextTests {
    @Test
    func render_withScreenContextEntries_interleavesEntriesChronologically() {
        let attributed: [AttributedTranscriptSegment] = [
            AttributedTranscriptSegment(startSeconds: 0, endSeconds: 5, speakerId: 1, text: "Hello."),
            AttributedTranscriptSegment(startSeconds: 9, endSeconds: 12, speakerId: 2, text: "Let’s review the roadmap.")
        ]
        let screenContextEntries: [TranscriptTimelineEntry] = [
            TranscriptTimelineEntry(
                kind: .screenContext,
                timestampStartSeconds: 6,
                displayLabel: "Screen Context",
                text: "Roadmap review in Figma",
                windowTitle: "Figma"
            )
        ]

        let markdown = TranscriptMarkdownRenderer().render(
            title: "Weekly Sync",
            dateISO: "2025-12-19",
            transcript: "unused when timeline entries provided",
            attributedSegments: attributed,
            screenContextEntries: screenContextEntries
        )

        let expected = """
        ---
        type: meeting_transcript
        date: 2025-12-19
        title: \"Weekly Sync\"
        source: \"Minute\"
        ---

        # Weekly Sync — Transcript

        Speaker 1 [00:00 - 00:05]
        Hello.

        Screen Context (Figma) [00:06]
        Roadmap review in Figma

        Speaker 2 [00:09 - 00:12]
        Let’s review the roadmap.
        """ + "\n"

        expectEqual(markdown, expected)
    }
}