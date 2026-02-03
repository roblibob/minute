import Foundation
import Testing
@testable import MinuteCore

struct OutputContractCoverageTests {
    @Test
    func meetingNoteDateFormatter_isDeterministicWithFixedLocaleAndTimeZone() {
        let calendar = Calendar(identifier: .gregorian)
        let components = DateComponents(calendar: calendar, timeZone: TimeZone(secondsFromGMT: 0), year: 2026, month: 1, day: 2, hour: 3, minute: 4)
        let date = calendar.date(from: components)!

        let locale = Locale(identifier: "en_US_POSIX")
        let timeZone = TimeZone(secondsFromGMT: 0)!
        let formatted = MeetingNoteDateFormatter.format(date, locale: locale, timeZone: timeZone)
        let normalized = formatted.replacingOccurrences(of: "\u{202F}", with: " ")

        expectEqual(normalized, "Jan 2, 2026 at 3:04 AM")
    }
}
