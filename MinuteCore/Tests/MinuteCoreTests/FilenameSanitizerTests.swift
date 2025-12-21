import XCTest
@testable import MinuteCore

final class FilenameSanitizerTests: XCTestCase {
    func testSanitizeTitle_whenEmpty_returnsUntitled() {
        XCTAssertEqual(FilenameSanitizer.sanitizeTitle(""), "Untitled")
        XCTAssertEqual(FilenameSanitizer.sanitizeTitle("   \n  "), "Untitled")
    }

    func testSanitizeTitle_removesPathSeparatorsAndForbiddenCharacters() {
        XCTAssertEqual(FilenameSanitizer.sanitizeTitle("A/B:C"), "A B C")
        XCTAssertEqual(FilenameSanitizer.sanitizeTitle("Hello\\World"), "Hello World")
        XCTAssertEqual(FilenameSanitizer.sanitizeTitle("What?*\"<>|"), "What")
    }

    func testSanitizeTitle_collapsesWhitespace() {
        XCTAssertEqual(FilenameSanitizer.sanitizeTitle("  Hello   world  "), "Hello world")
    }

    func testSanitizeTitle_preventsDotSegments() {
        XCTAssertEqual(FilenameSanitizer.sanitizeTitle("."), "Untitled")
        XCTAssertEqual(FilenameSanitizer.sanitizeTitle(".."), "Untitled")
    }
}
