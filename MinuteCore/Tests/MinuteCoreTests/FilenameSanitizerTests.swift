import Testing
import Foundation
@testable import MinuteCore

struct FilenameSanitizerTests {
    @Test
    func sanitizeTitle_whenEmpty_returnsUntitled() {
        expectEqual(FilenameSanitizer.sanitizeTitle(""), "Untitled")
        expectEqual(FilenameSanitizer.sanitizeTitle("   \n  "), "Untitled")
    }

    @Test
    func sanitizeTitle_removesPathSeparatorsAndForbiddenCharacters() {
        expectEqual(FilenameSanitizer.sanitizeTitle("A/B:C"), "A B C")
        expectEqual(FilenameSanitizer.sanitizeTitle("Hello\\World"), "Hello World")
        expectEqual(FilenameSanitizer.sanitizeTitle("What?*\"<>|"), "What")
    }

    @Test
    func sanitizeTitle_collapsesWhitespace() {
        expectEqual(FilenameSanitizer.sanitizeTitle("  Hello   world  "), "Hello world")
    }

    @Test
    func sanitizeTitle_preventsDotSegments() {
        expectEqual(FilenameSanitizer.sanitizeTitle("."), "Untitled")
        expectEqual(FilenameSanitizer.sanitizeTitle(".."), "Untitled")
    }
}
