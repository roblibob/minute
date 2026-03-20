import Foundation
import Testing
@testable import MinuteCore

struct MeetingNoteParsingScreenContextTests {
    @Test
    func parseTranscriptTimelineEntries_roundTripsSpeakerAndScreenContextEntries() {
        let markdown = """
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
        """

        let entries = MeetingNoteParsing.parseTranscriptTimelineEntries(fromTranscriptMarkdown: markdown)

        expectEqual(entries.count, 3)
        expectEqual(entries[0].kind, .speakerSegment)
        expectEqual(entries[0].speakerId, 1)
        expectEqual(entries[0].timestampStartSeconds, 0)
        expectEqual(entries[0].timestampEndSeconds, 5)
        expectEqual(entries[0].text, "Hello.")

        expectEqual(entries[1].kind, .screenContext)
        expectEqual(entries[1].displayLabel, "Screen Context")
        expectEqual(entries[1].timestampStartSeconds, 6)
        expectEqual(entries[1].windowTitle, "Figma")
        expectEqual(entries[1].text, "Roadmap review in Figma")

        expectEqual(entries[2].kind, .speakerSegment)
        expectEqual(entries[2].speakerId, 2)
    }

    @Test
    func summarizationSourceText_reconstructsTimelineTextIncludingScreenContext() {
        let markdown = """
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
        """

        let source = MeetingNoteParsing.summarizationSourceText(fromTranscriptMarkdown: markdown)

        expectEqual(source, "[00:00] Speaker 1: Hello.\n[00:06] Screen context - Roadmap review in Figma")
    }

    @Test
    func noteMayContainUserEdits_flagsUnexpectedManualContent() {
        let markdown = """
        ---
        type: meeting
        date: 2026-03-20 09.41
        title: \"Product Review\"
        source: \"Minute\"
        meeting_type: planning
        tags:
        ---

        # Product Review

        ## Summary
        Recovered planning summary.

        ## Decisions
        - Move launch review to next week.

        ## Transcript
        [[Meetings/_transcripts/2026-03-20 09.41 - Product Review.md]]

        Personal follow-up note outside managed sections.
        """

        #expect(MeetingNoteParsing.noteMayContainUserEdits(inNoteMarkdown: markdown))
    }
}