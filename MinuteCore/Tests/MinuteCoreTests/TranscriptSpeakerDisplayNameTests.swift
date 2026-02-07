import Testing
import Foundation
@testable import MinuteCore

struct TranscriptSpeakerDisplayNameTests {
    @Test
    func render_withSpeakerDisplayNames_replacesSpeakerLabelWhenPresent() {
        let attributed: [AttributedTranscriptSegment] = [
            AttributedTranscriptSegment(startSeconds: 0, endSeconds: 5, speakerId: 1, text: "Hello."),
            AttributedTranscriptSegment(startSeconds: 5, endSeconds: 8, speakerId: 2, text: "Hi there."),
        ]

        let markdown = TranscriptMarkdownRenderer().render(
            title: "Weekly Sync",
            dateISO: "2025-12-19",
            transcript: "unused",
            attributedSegments: attributed,
            speakerDisplayNames: [1: "Alice"]
        )

        #expect(markdown.contains("Speaker 1 (Alice) [00:00 - 00:05]\nHello."))
        #expect(markdown.contains("Speaker 2 [00:05 - 00:08]\nHi there."))
    }
}
