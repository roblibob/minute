import Testing
import Foundation
@testable import MinuteCore

struct TranscriptSpeakerHeadingRewriterTests {
    @Test
    func rewrite_onlyRewritesMinuteHeadingLines() {
        let input = """
        ---
        type: meeting_transcript
        ---

        # Weekly Sync — Transcript

        Speaker 1 [00:00 - 00:05]
        Hello Speaker 1.

        Speaker 2 [00:05 - 00:08]
        Hi there.

        Speaker 1 is not a heading.
        """ + "\n"

        let output = TranscriptSpeakerHeadingRewriter.rewrite(
            transcriptMarkdown: input,
            speakerDisplayNames: [1: "Alice", 2: "Bob"]
        )

        #expect(output.contains("Speaker 1 (Alice) [00:00 - 00:05]\nHello Speaker 1."))
        #expect(output.contains("Speaker 2 (Bob) [00:05 - 00:08]\nHi there."))
        #expect(output.contains("Speaker 1 is not a heading."))
    }

    @Test
    func rewrite_preservesTrailingNewline() {
        let input = "Speaker 1 [00:00 - 00:01]\nHi\n"
        let output = TranscriptSpeakerHeadingRewriter.rewrite(
            transcriptMarkdown: input,
            speakerDisplayNames: [1: "Alice"]
        )

        #expect(output.hasSuffix("\n"))
    }

    @Test
    func rewrite_updatesAlreadyRenamedHeading_whenPriorMappingProvided() {
        let input = "Alice [00:00 - 00:01]\nHi\n"
        let output = TranscriptSpeakerHeadingRewriter.rewrite(
            transcriptMarkdown: input,
            speakerDisplayNames: [1: "Bob"],
            priorSpeakerDisplayNames: [1: "Alice"]
        )

        #expect(output == "Speaker 1 (Bob) [00:00 - 00:01]\nHi\n")
    }
}
