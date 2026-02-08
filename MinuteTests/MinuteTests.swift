import Foundation
import Testing
@testable import Minute

struct MinuteTests {
    @Test
    func smoke() {
        #expect(Bool(true))
    }
}

struct MeetingNotesBrowserViewModelSpeakerDraftIsolationTests {
    @Test
    func parseSpeakerIDs_parsesUniqueSortedIDs() {
        let transcript = """
        Speaker 2 [00:00]
        Hello

        Speaker 10 [00:05]
        Hi

        Speaker 2 [00:06]
        Again
        """

        let ids = MeetingNotesBrowserViewModel.parseSpeakerIDs(fromTranscriptMarkdown: transcript)
        #expect(ids == [2, 10])
    }

    @Test
    func rewriteSpeakerHeadingsForDisplay_replacesNamedHeadingsOnly() {
        let transcript = """
            Speaker 1 [00:00]
            Hello

        Speaker 2 [00:05]
            Hi

        Speaker 3
        Unchanged
        """

        let rewritten = MeetingNotesBrowserViewModel.rewriteSpeakerHeadingsForDisplay(
            transcriptMarkdown: transcript,
            speakerDisplayNames: [1: "Alice", 2: " Bob "]
        )

        #expect(rewritten.contains("Alice [00:00]"))
        #expect(rewritten.contains("Bob [00:05]"))
        #expect(rewritten.contains("Speaker 3"))
    }
}
