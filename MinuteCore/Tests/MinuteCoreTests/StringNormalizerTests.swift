import Testing
import Foundation
@testable import MinuteCore

struct StringNormalizerTests {
    @Test
    func normalizeParagraph_normalizesLineEndingsAndTrims() {
        let raw = "  Line 1\r\nLine 2\rLine 3\n  "
        let normalized = StringNormalizer.normalizeParagraph(raw)
        expectEqual(normalized, "Line 1\nLine 2\nLine 3")
    }

    @Test
    func normalizeInline_flattensWhitespaceToSingleLine() {
        let raw = "Hello\r\nWorld\tTest"
        let normalized = StringNormalizer.normalizeInline(raw)
        expectEqual(normalized, "Hello World Test")
    }

    @Test
    func normalizeTitle_returnsUntitledWhenEmpty() {
        let normalized = StringNormalizer.normalizeTitle(" \n\t ")
        expectEqual(normalized, "Untitled")
    }

    @Test
    func yamlDoubleQuoted_escapesBackslashesQuotesAndNewlines() {
        let raw = "He said \"Hi\"\\There\nNext"
        let normalized = StringNormalizer.yamlDoubleQuoted(raw)
        expectEqual(normalized, "\"He said \\\"Hi\\\"\\\\There\\nNext\"")
    }
}
