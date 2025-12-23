import Foundation

public struct MeetingNoteItem: Sendable, Identifiable, Equatable {
    public var id: String { relativePath }
    public var title: String
    public var date: Date?
    public var relativePath: String
    public var fileURL: URL

    public init(title: String, date: Date?, relativePath: String, fileURL: URL) {
        self.title = title
        self.date = date
        self.relativePath = relativePath
        self.fileURL = fileURL
    }
}

public protocol MeetingNotesBrowsing: Sendable {
    func listNotes() async throws -> [MeetingNoteItem]
    func loadNoteContent(for item: MeetingNoteItem) async throws -> String
}

public struct VaultMeetingNotesBrowser: MeetingNotesBrowsing, @unchecked Sendable {
    private struct NoteCandidate {
        var item: MeetingNoteItem
        var sortDate: Date
    }

    private let vaultAccess: VaultAccess
    private let meetingsRelativePath: String

    public init(vaultAccess: VaultAccess, meetingsRelativePath: String = "Meetings") {
        self.vaultAccess = vaultAccess
        self.meetingsRelativePath = meetingsRelativePath
    }

    public init(vaultAccess: VaultAccess, configuration: VaultConfiguration) {
        self.vaultAccess = vaultAccess
        self.meetingsRelativePath = configuration.meetingsRelativePath
    }

    public func listNotes() async throws -> [MeetingNoteItem] {
        try Task.checkCancellation()

        return try vaultAccess.withVaultAccess { vaultRootURL in
            let meetingsRootURL = Self.meetingsRootURL(from: vaultRootURL, meetingsRelativePath: meetingsRelativePath)
            guard FileManager.default.fileExists(atPath: meetingsRootURL.path) else {
                return []
            }

            let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .contentModificationDateKey]
            let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
            guard let enumerator = FileManager.default.enumerator(
                at: meetingsRootURL,
                includingPropertiesForKeys: Array(resourceKeys),
                options: options
            ) else {
                return []
            }

            var candidates: [NoteCandidate] = []

            for case let url as URL in enumerator {
                try Task.checkCancellation()

                let values = try url.resourceValues(forKeys: resourceKeys)
                if values.isDirectory == true {
                    if Self.isExcludedDirectory(url) {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                guard url.pathExtension.lowercased() == "md" else { continue }

                let filename = url.deletingPathExtension().lastPathComponent
                let parseResult = Self.parseFilename(filename)

                let relativePath = Self.relativePath(from: vaultRootURL, to: url)
                let sortDate = parseResult.date ?? values.contentModificationDate ?? Date.distantPast

                let item = MeetingNoteItem(
                    title: parseResult.title,
                    date: parseResult.date,
                    relativePath: relativePath,
                    fileURL: url
                )
                candidates.append(NoteCandidate(item: item, sortDate: sortDate))
            }

            return candidates
                .sorted { $0.sortDate > $1.sortDate }
                .map(\.item)
        }
    }

    public func loadNoteContent(for item: MeetingNoteItem) async throws -> String {
        try Task.checkCancellation()

        return try vaultAccess.withVaultAccess { _ in
            let data = try Data(contentsOf: item.fileURL)
            if let content = String(data: data, encoding: .utf8) {
                return content
            }
            return String(decoding: data, as: UTF8.self)
        }
    }

    private static func meetingsRootURL(from vaultRootURL: URL, meetingsRelativePath: String) -> URL {
        let components = normalizedRelative(meetingsRelativePath)
        return components.reduce(vaultRootURL) { partial, component in
            partial.appendingPathComponent(component, isDirectory: true)
        }
    }

    private static func normalizedRelative(_ path: String) -> [String] {
        path
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    private static func isExcludedDirectory(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        return name == "_audio" || name == "_transcripts"
    }

    private static func relativePath(from vaultRootURL: URL, to fileURL: URL) -> String {
        let rootPath = vaultRootURL.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        if filePath.hasPrefix(rootPath) {
            var suffix = String(filePath.dropFirst(rootPath.count))
            if suffix.hasPrefix("/") { suffix.removeFirst() }
            return suffix
        }
        return fileURL.lastPathComponent
    }

    private struct ParsedFilename {
        var title: String
        var date: Date?
    }

    private static func parseFilename(_ filename: String) -> ParsedFilename {
        guard let separatorRange = filename.range(of: " - ") else {
            return ParsedFilename(title: filename, date: nil)
        }

        let datePart = String(filename[..<separatorRange.lowerBound])
        let titlePart = String(filename[separatorRange.upperBound...])

        let date = parseDateTimePrefix(datePart)
        let title = titlePart.isEmpty ? filename : titlePart
        return ParsedFilename(title: title, date: date)
    }

    private static func parseDateTimePrefix(_ value: String, calendar: Calendar = .current) -> Date? {
        let parts = value.split(separator: " ")
        guard let datePart = parts.first else { return nil }

        let dateSegments = datePart.split(separator: "-")
        guard dateSegments.count == 3,
              let year = Int(dateSegments[0]),
              let month = Int(dateSegments[1]),
              let day = Int(dateSegments[2]) else {
            return nil
        }

        var hour = 0
        var minute = 0
        if parts.count > 1 {
            let rawTime = parts[1]
            let timeSegments = rawTime.split(separator: ":")
            let fallbackSegments = rawTime.split(separator: ".")
            let segments = timeSegments.count == 2 ? timeSegments : fallbackSegments
            if segments.count == 2,
               let parsedHour = Int(segments[0]),
               let parsedMinute = Int(segments[1]) {
                hour = parsedHour
                minute = parsedMinute
            }
        }

        var cal = calendar
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone

        var components = DateComponents()
        components.calendar = cal
        components.timeZone = cal.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute

        return cal.date(from: components)
    }
}
