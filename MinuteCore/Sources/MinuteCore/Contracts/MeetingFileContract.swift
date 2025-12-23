import Foundation

/// Computes deterministic output paths for the fixed v1 vault contract.
public struct MeetingFileContract: Sendable {
    public struct VaultFolders: Sendable {
        /// Relative to vault root. Default: `Meetings`
        public var meetingsRoot: String
        /// Relative to vault root. Default: `Meetings/_audio`
        public var audioRoot: String
        /// Relative to vault root. Default: `Meetings/_transcripts`
        public var transcriptsRoot: String

        public init(
            meetingsRoot: String = "Meetings",
            audioRoot: String = "Meetings/_audio",
            transcriptsRoot: String = "Meetings/_transcripts"
        ) {
            self.meetingsRoot = meetingsRoot
            self.audioRoot = audioRoot
            self.transcriptsRoot = transcriptsRoot
        }
    }

    public var folders: VaultFolders

    public init(folders: VaultFolders = VaultFolders()) {
        self.folders = folders
    }

    public func noteRelativePath(date: Date, title: String, calendar: Calendar = .current) -> String {
        let y = String(format: "%04d", calendar.component(.year, from: date))
        let m = String(format: "%02d", calendar.component(.month, from: date))
        let d = Self.isoDateTimePrefix(date, calendar: calendar)
        let safeTitle = FilenameSanitizer.sanitizeTitle(title)

        return [
            folders.meetingsRoot,
            y,
            m,
            "\(d) - \(safeTitle).md",
        ].joined(separator: "/")
    }

    public func audioRelativePath(date: Date, title: String, calendar: Calendar = .current) -> String {
        let d = Self.isoDateTimePrefix(date, calendar: calendar)
        let safeTitle = FilenameSanitizer.sanitizeTitle(title)

        return [
            folders.audioRoot,
            "\(d) - \(safeTitle).wav",
        ].joined(separator: "/")
    }

    public func transcriptRelativePath(date: Date, title: String, calendar: Calendar = .current) -> String {
        let d = Self.isoDateTimePrefix(date, calendar: calendar)
        let safeTitle = FilenameSanitizer.sanitizeTitle(title)

        return [
            folders.transcriptsRoot,
            "\(d) - \(safeTitle).md",
        ].joined(separator: "/")
    }

    public static func isoDate(_ date: Date, calendar: Calendar = .current) -> String {
        var cal = calendar
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone

        let y = String(format: "%04d", cal.component(.year, from: date))
        let m = String(format: "%02d", cal.component(.month, from: date))
        let d = String(format: "%02d", cal.component(.day, from: date))
        return "\(y)-\(m)-\(d)"
    }

    public static func isoDateTimePrefix(_ date: Date, calendar: Calendar = .current) -> String {
        var cal = calendar
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone

        let y = String(format: "%04d", cal.component(.year, from: date))
        let m = String(format: "%02d", cal.component(.month, from: date))
        let d = String(format: "%02d", cal.component(.day, from: date))
        let h = String(format: "%02d", cal.component(.hour, from: date))
        let min = String(format: "%02d", cal.component(.minute, from: date))
        return "\(y)-\(m)-\(d) \(h).\(min)"
    }
}
