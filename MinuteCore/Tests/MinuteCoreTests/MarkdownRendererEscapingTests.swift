import XCTest
@testable import MinuteCore

final class MarkdownRendererEscapingTests: XCTestCase {
    func testTitle_isDoubleQuotedAndEscapedInYAML_andNormalizedInHeader() {
        let extraction = MeetingExtraction(
            title: "He said \"Hello\\World\"\nNext",
            date: "2025-12-19",
            summary: "",
            decisions: [],
            actionItems: [],
            openQuestions: [],
            keyPoints: []
        )

        let audio = "Meetings/_audio/2025-12-19 - Anything.wav"
        let markdown = MarkdownRenderer().render(
            extraction: extraction,
            noteDateTime: "2025-12-19 10:00",
            audioRelativePath: audio,
            transcriptRelativePath: nil
        )

        // YAML must be double-quoted and escaped.
        XCTAssertTrue(markdown.contains("title: \"He said \\\"Hello\\\\World\\\" Next\"\n"))

        // Header title is normalized to a single line.
        XCTAssertTrue(markdown.contains("# He said \"Hello\\World\" Next\n"))
    }
}
