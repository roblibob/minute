import Testing
import Foundation
@testable import MinuteCore

struct MarkdownRendererEscapingTests {
    @Test
    func title_isDoubleQuotedAndEscapedInYAML_andNormalizedInHeader() {
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
            audioDurationSeconds: nil,
            audioRelativePath: audio,
            transcriptRelativePath: nil
        )

        #expect(markdown.contains("title: \"He said \\\"Hello\\\\World\\\" Next\"\n"))
        #expect(markdown.contains("# He said \"Hello\\World\" Next\n"))
    }
}
