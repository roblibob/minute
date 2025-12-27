import Foundation

public enum MeetingNoteDateFormatter {
    private static let lock = NSLock()
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    public static func format(
        _ date: Date,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        lock.lock()
        defer { lock.unlock() }

        formatter.locale = locale
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}
