import Testing
import Foundation
@testable import MinuteCore

struct TranscriptMarkdownRendererSpeakerLabelsTests {
    @Test
    func render_withAttributedSegments_rendersDeterministicSpeakerHeadings() throws {
        let attributed: [AttributedTranscriptSegment] = [
            AttributedTranscriptSegment(startSeconds: 0, endSeconds: 5, speakerId: 1, text: "Hello."),
            AttributedTranscriptSegment(startSeconds: 5, endSeconds: 8, speakerId: 2, text: "Hi there."),
            AttributedTranscriptSegment(startSeconds: 8, endSeconds: 10, speakerId: 1, text: "Let’s start."),
        ]

        let markdown = TranscriptMarkdownRenderer().render(
            title: "Weekly Sync",
            dateISO: "2025-12-19",
            transcript: "unused when attributedSegments provided",
            attributedSegments: attributed
        )

        let fixtureURL = try #require(Bundle.module.url(forResource: "speaker_headings", withExtension: "md"))
        let fixture = try String(contentsOf: fixtureURL)
        let marker = "\n---\n\n"
        let markerRange = try #require(fixture.range(of: marker))
        let expectedBody = String(fixture[markerRange.upperBound...])

        let anchor = "# Weekly Sync — Transcript\n\n"
        let renderedBody = try #require(markdown.components(separatedBy: anchor).last)

        expectEqual(renderedBody, expectedBody)
    }
}
