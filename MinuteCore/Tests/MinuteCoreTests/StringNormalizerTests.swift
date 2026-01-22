import XCTest
@testable import MinuteCore

final class StringNormalizerTests: XCTestCase {
    func testNormalizeParagraph_normalizesLineEndingsAndTrims() {
        let raw = "  Line 1\r\nLine 2\rLine 3\n  "
        let normalized = StringNormalizer.normalizeParagraph(raw)
        XCTAssertEqual(normalized, "Line 1\nLine 2\nLine 3")
    }

    func testNormalizeInline_flattensWhitespaceToSingleLine() {
        let raw = "Hello\r\nWorld\tTest"
        let normalized = StringNormalizer.normalizeInline(raw)
        XCTAssertEqual(normalized, "Hello World Test")
    }

    func testNormalizeTitle_returnsUntitledWhenEmpty() {
        let normalized = StringNormalizer.normalizeTitle(" \n\t ")
        XCTAssertEqual(normalized, "Untitled")
    }

    func testYamlDoubleQuoted_escapesBackslashesQuotesAndNewlines() {
        let raw = "He said \"Hi\"\\There\nNext"
        let normalized = StringNormalizer.yamlDoubleQuoted(raw)
        XCTAssertEqual(normalized, "\"He said \\\"Hi\\\"\\\\There\\nNext\"")
    }
}
