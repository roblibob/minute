import XCTest
@testable import MinuteCore

final class TranscriptMarkdownRendererTests: XCTestCase {
    func testRender_producesDeterministicMarkdown() {
        let markdown = TranscriptMarkdownRenderer().render(
            title: "Weekly Sync",
            dateISO: "2025-12-19",
            transcript: "Hello\n\nWorld"
        )

        let expected = """
        ---
        type: meeting_transcript
        date: 2025-12-19
        title: \"Weekly Sync\"
        source: \"Minute\"
        ---

        # Weekly Sync — Transcript

        Hello

        World
        """ + "\n"

        XCTAssertEqual(markdown, expected)
    }
}
