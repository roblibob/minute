import Foundation

public enum MinuteISODate {
    public static func format(_ date: Date, calendar: Calendar = .current) -> String {
        MeetingFileContract.isoDate(date, calendar: calendar)
    }

    public static func parse(_ value: String, calendar: Calendar = .current) -> Date? {
        let parts = value.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let d = Int(parts[2])
        else {
            return nil
        }

        var cal = calendar
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone

        var components = DateComponents()
        components.calendar = cal
        components.timeZone = cal.timeZone
        components.year = y
        components.month = m
        components.day = d
        components.hour = 0
        components.minute = 0
        components.second = 0

        return cal.date(from: components)
    }
}
