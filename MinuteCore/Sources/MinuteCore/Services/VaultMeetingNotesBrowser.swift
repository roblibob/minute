import Foundation

public struct MeetingNoteItem: Sendable, Identifiable, Equatable {
    public var id: String { relativePath }
    public var title: String
    public var date: Date?
    public var relativePath: String
    public var fileURL: URL
    public var hasTranscript: Bool
    public var transcriptURL: URL?
    public var currentMeetingTypeId: String?
    public var reprocessBlockingReason: ReprocessBlockingReason?

    public init(
        title: String,
        date: Date?,
        relativePath: String,
        fileURL: URL,
        hasTranscript: Bool = false,
        transcriptURL: URL? = nil,
        currentMeetingTypeId: String? = nil,
        reprocessBlockingReason: ReprocessBlockingReason? = nil
    ) {
        self.title = title
        self.date = date
        self.relativePath = relativePath
        self.fileURL = fileURL
        self.hasTranscript = hasTranscript
        self.transcriptURL = transcriptURL
        self.currentMeetingTypeId = currentMeetingTypeId
        self.reprocessBlockingReason = reprocessBlockingReason
    }
}

public protocol MeetingNotesBrowsing: Sendable {
    func listNotes() async throws -> [MeetingNoteItem]
    func loadNoteContent(for item: MeetingNoteItem) async throws -> String
    func loadTranscriptContent(for item: MeetingNoteItem) async throws -> String
    func deleteNoteFiles(for item: MeetingNoteItem) async throws
    /// Renames the note title: moves the summary, audio, and transcript files to
    /// the new base name and rewrites the note/transcript markdown (frontmatter
    /// title, headings, wiki-links). Returns the updated item.
    @discardableResult
    func renameNoteFiles(for item: MeetingNoteItem, to newTitle: String) async throws -> MeetingNoteItem
}

public struct VaultMeetingNotesBrowser: MeetingNotesBrowsing, @unchecked Sendable {
    private enum TranscriptArtifactState {
        case missing
        case available
        case unreadable
    }

    private struct NoteCandidate {
        var item: MeetingNoteItem
        var sortDate: Date
    }

    private let vaultAccess: VaultAccess
    private let meetingsRelativePath: String
    private let audioRelativePath: String
    private let transcriptsRelativePath: String

    public init(
        vaultAccess: VaultAccess,
        meetingsRelativePath: String = AppConfiguration.Defaults.defaultMeetingsRelativePath,
        audioRelativePath: String = AppConfiguration.Defaults.defaultAudioRelativePath,
        transcriptsRelativePath: String = AppConfiguration.Defaults.defaultTranscriptsRelativePath
    ) {
        self.vaultAccess = vaultAccess
        self.meetingsRelativePath = meetingsRelativePath
        self.audioRelativePath = audioRelativePath
        self.transcriptsRelativePath = transcriptsRelativePath
    }

    public init(vaultAccess: VaultAccess, configuration: VaultConfiguration) {
        self.vaultAccess = vaultAccess
        self.meetingsRelativePath = configuration.meetingsRelativePath
        self.audioRelativePath = configuration.audioRelativePath
        self.transcriptsRelativePath = configuration.transcriptsRelativePath
    }

    public func listNotes() async throws -> [MeetingNoteItem] {
        try Task.checkCancellation()

        return try vaultAccess.withVaultAccess { vaultRootURL in
            let meetingsRootURL = Self.meetingsRootURL(from: vaultRootURL, meetingsRelativePath: meetingsRelativePath)
            guard FileManager.default.fileExists(atPath: meetingsRootURL.path) else {
                return []
            }
            let transcriptRootURL = Self.directoryURL(from: vaultRootURL, relativePath: transcriptsRelativePath)

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
                let transcriptURL = transcriptRootURL.appendingPathComponent("\(filename).md")
                let transcriptState = Self.transcriptArtifactState(at: transcriptURL)
                let hasTranscript = transcriptState == .available
                let currentMeetingTypeId = Self.loadCurrentMeetingTypeID(from: url)
                let reprocessBlockingReason: ReprocessBlockingReason?
                switch transcriptState {
                case .missing:
                    reprocessBlockingReason = .missingTranscript
                case .available:
                    reprocessBlockingReason = nil
                case .unreadable:
                    reprocessBlockingReason = .unreadableTranscript
                }

                let item = MeetingNoteItem(
                    title: parseResult.title,
                    date: parseResult.date,
                    relativePath: relativePath,
                    fileURL: url,
                    hasTranscript: hasTranscript,
                    transcriptURL: transcriptURL,
                    currentMeetingTypeId: currentMeetingTypeId,
                    reprocessBlockingReason: reprocessBlockingReason
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

    public func loadTranscriptContent(for item: MeetingNoteItem) async throws -> String {
        try Task.checkCancellation()

        return try vaultAccess.withVaultAccess { vaultRootURL in
            let transcriptURL: URL
            if let provided = item.transcriptURL {
                transcriptURL = provided
            } else {
                let baseName = item.fileURL.deletingPathExtension().lastPathComponent
                let transcriptRootURL = Self.directoryURL(from: vaultRootURL, relativePath: transcriptsRelativePath)
                transcriptURL = transcriptRootURL.appendingPathComponent("\(baseName).md")
            }
            let data = try Data(contentsOf: transcriptURL)
            if let content = String(data: data, encoding: .utf8) {
                return content
            }
            return String(decoding: data, as: UTF8.self)
        }
    }

    public func deleteNoteFiles(for item: MeetingNoteItem) async throws {
        try Task.checkCancellation()

        return try vaultAccess.withVaultAccess { vaultRootURL in
            let baseName = item.fileURL.deletingPathExtension().lastPathComponent
            let audioRootURL = Self.directoryURL(from: vaultRootURL, relativePath: audioRelativePath)
            let transcriptRootURL = Self.directoryURL(from: vaultRootURL, relativePath: transcriptsRelativePath)

            let audioURL = audioRootURL.appendingPathComponent("\(baseName).wav")
            let transcriptURL = item.transcriptURL ?? transcriptRootURL.appendingPathComponent("\(baseName).md")

            let urls = [item.fileURL, audioURL, transcriptURL]
            var firstError: Error?

            for url in urls {
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                do {
                    var trashedURL: NSURL?
                    try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
                } catch {
                    if firstError == nil {
                        firstError = error
                    }
                }
            }

            if let firstError {
                throw firstError
            }
        }
    }

    @discardableResult
    public func renameNoteFiles(for item: MeetingNoteItem, to newTitle: String) async throws -> MeetingNoteItem {
        try Task.checkCancellation()

        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw MeetingNoteRenameError.emptyTitle
        }

        return try vaultAccess.withVaultAccess { vaultRootURL in
            let oldBaseName = item.fileURL.deletingPathExtension().lastPathComponent
            let newBaseName = MeetingNoteRenamer.newBaseName(oldBaseName: oldBaseName, newTitle: trimmedTitle)
            let sanitizedNewTitle = FilenameSanitizer.sanitizeTitle(trimmedTitle)

            guard newBaseName != oldBaseName else {
                throw MeetingNoteRenameError.titleUnchanged
            }

            let audioRootURL = Self.directoryURL(from: vaultRootURL, relativePath: audioRelativePath)
            let transcriptRootURL = Self.directoryURL(from: vaultRootURL, relativePath: transcriptsRelativePath)

            let oldNoteURL = item.fileURL
            let oldAudioURL = audioRootURL.appendingPathComponent("\(oldBaseName).wav")
            let oldTranscriptURL = item.transcriptURL
                ?? transcriptRootURL.appendingPathComponent("\(oldBaseName).md")

            let newNoteURL = oldNoteURL.deletingLastPathComponent().appendingPathComponent("\(newBaseName).md")
            let newAudioURL = audioRootURL.appendingPathComponent("\(newBaseName).wav")
            let newTranscriptURL = transcriptRootURL.appendingPathComponent("\(newBaseName).md")

            let fileManager = FileManager.default
            let plannedMoves: [(from: URL, to: URL)] = [
                (oldNoteURL, newNoteURL),
                (oldAudioURL, newAudioURL),
                (oldTranscriptURL, newTranscriptURL),
            ].filter { fileManager.fileExists(atPath: $0.from.path) }

            // Refuse to overwrite anything at the destinations.
            for move in plannedMoves where fileManager.fileExists(atPath: move.to.path) {
                throw MeetingNoteRenameError.destinationAlreadyExists
            }

            // Rewrite markdown contents BEFORE moving, so a content failure
            // leaves the vault untouched.
            let noteMarkdown = try String(contentsOf: oldNoteURL, encoding: .utf8)
            let rewrittenNote = MeetingNoteRenamer.rewrittenNoteMarkdown(
                noteMarkdown,
                oldTitle: item.title,
                newTitle: sanitizedNewTitle,
                oldBaseName: oldBaseName,
                newBaseName: newBaseName
            )

            var rewrittenTranscript: String?
            if fileManager.fileExists(atPath: oldTranscriptURL.path),
               let transcriptMarkdown = try? String(contentsOf: oldTranscriptURL, encoding: .utf8) {
                rewrittenTranscript = MeetingNoteRenamer.rewrittenTranscriptMarkdown(
                    transcriptMarkdown,
                    oldTitle: item.title,
                    newTitle: sanitizedNewTitle
                )
            }

            // Move files, rolling back completed moves on failure.
            var completedMoves: [(from: URL, to: URL)] = []
            do {
                for move in plannedMoves {
                    try fileManager.moveItem(at: move.from, to: move.to)
                    completedMoves.append(move)
                }
            } catch {
                for move in completedMoves.reversed() {
                    try? fileManager.moveItem(at: move.to, to: move.from)
                }
                throw error
            }

            // Write rewritten contents at the new locations (atomic writes).
            try Data(rewrittenNote.utf8).write(to: newNoteURL, options: [.atomic])
            if let rewrittenTranscript {
                try Data(rewrittenTranscript.utf8).write(to: newTranscriptURL, options: [.atomic])
            }

            var renamed = item
            renamed.title = sanitizedNewTitle
            renamed.fileURL = newNoteURL
            renamed.relativePath = Self.relativePath(from: vaultRootURL, to: newNoteURL)
            renamed.transcriptURL = fileManager.fileExists(atPath: newTranscriptURL.path) ? newTranscriptURL : nil
            renamed.hasTranscript = renamed.transcriptURL != nil
            return renamed
        }
    }

    private static func meetingsRootURL(from vaultRootURL: URL, meetingsRelativePath: String) -> URL {
        VaultPathNormalizer.directoryURL(from: vaultRootURL, relativePath: meetingsRelativePath)
    }

    private static func directoryURL(from vaultRootURL: URL, relativePath: String) -> URL {
        VaultPathNormalizer.directoryURL(from: vaultRootURL, relativePath: relativePath)
    }

    private static func isExcludedDirectory(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        return name == "_audio" || name == "_transcripts"
    }

    private static func relativePath(from vaultRootURL: URL, to fileURL: URL) -> String {
        VaultPathNormalizer.relativePath(from: vaultRootURL, to: fileURL)
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

    private static func loadCurrentMeetingTypeID(from noteURL: URL) -> String? {
        guard let data = try? Data(contentsOf: noteURL) else {
            return nil
        }

        let markdown = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        return MeetingNoteParsing.parseMeetingTypeID(fromNoteMarkdown: markdown)
    }

    private static func transcriptArtifactState(at transcriptURL: URL) -> TranscriptArtifactState {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: transcriptURL.path, isDirectory: &isDirectory) else {
            return .missing
        }
        guard !isDirectory.boolValue else {
            return .unreadable
        }
        guard FileManager.default.isReadableFile(atPath: transcriptURL.path) else {
            return .unreadable
        }
        return .available
    }
}
