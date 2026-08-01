import Foundation

/// Errors surfaced when renaming a meeting note and its vault artifacts.
public enum MeetingNoteRenameError: Error, Sendable, Equatable, LocalizedError {
    /// The new title is empty after trimming/sanitization.
    case emptyTitle
    /// The sanitized title matches the current one; nothing to rename.
    case titleUnchanged
    /// A file already exists at one of the destination paths.
    case destinationAlreadyExists

    public var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Enter a title for the note."
        case .titleUnchanged:
            return "The new title matches the current title."
        case .destinationAlreadyExists:
            return "A note with that title already exists for the same date and time."
        }
    }
}

/// Pure helpers for renaming a meeting note: computes the renamed base name and
/// rewrites note/transcript markdown (frontmatter title, headings, wiki-links).
///
/// File-system orchestration lives in `VaultMeetingNotesBrowser.renameNoteFiles`.
public enum MeetingNoteRenamer {

    /// Computes the new vault base name (filename without extension), keeping the
    /// `YYYY-MM-DD HH.MM` prefix from the old base name when present.
    public static func newBaseName(oldBaseName: String, newTitle: String) -> String {
        let safeTitle = FilenameSanitizer.sanitizeTitle(newTitle)
        guard let separatorRange = oldBaseName.range(of: " - ") else {
            return safeTitle
        }
        let prefix = String(oldBaseName[..<separatorRange.lowerBound])
        return "\(prefix) - \(safeTitle)"
    }

    /// Rewrites the meeting note markdown for a rename:
    /// - frontmatter `title:` line
    /// - the first `# ` heading matching the old title
    /// - `[[wiki-links]]` containing the old base name (Audio/Transcript sections)
    ///
    /// Body prose mentioning the old title is intentionally left untouched.
    public static func rewrittenNoteMarkdown(
        _ markdown: String,
        oldTitle: String,
        newTitle: String,
        oldBaseName: String,
        newBaseName: String
    ) -> String {
        var lines = markdown.components(separatedBy: "\n")
        var replacedHeading = false

        for index in lines.indices {
            let line = lines[index]

            if isFrontmatterTitleLine(line) {
                lines[index] = "title: \(StringNormalizer.yamlDoubleQuoted(newTitle))"
                continue
            }

            if !replacedHeading, isHeadingLine(line, matching: oldTitle) {
                lines[index] = "# \(newTitle)"
                replacedHeading = true
                continue
            }

            if line.contains("[[") && line.contains(oldBaseName) {
                lines[index] = line.replacingOccurrences(of: oldBaseName, with: newBaseName)
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Rewrites the transcript markdown for a rename: frontmatter `title:` line
    /// and the `# <title> — Transcript` heading. The transcript body is untouched.
    public static func rewrittenTranscriptMarkdown(
        _ markdown: String,
        oldTitle: String,
        newTitle: String
    ) -> String {
        let safeOldTitle = FilenameSanitizer.sanitizeTitle(oldTitle)
        let safeNewTitle = FilenameSanitizer.sanitizeTitle(newTitle)

        var lines = markdown.components(separatedBy: "\n")
        var replacedHeading = false

        for index in lines.indices {
            let line = lines[index]

            if isFrontmatterTitleLine(line) {
                lines[index] = "title: \(StringNormalizer.yamlDoubleQuoted(safeNewTitle))"
                continue
            }

            if !replacedHeading, line.hasPrefix("# ") {
                let heading = String(line.dropFirst(2))
                if heading == "\(safeOldTitle) — Transcript" || heading == safeOldTitle || heading == oldTitle {
                    let suffix = heading.hasSuffix("— Transcript") ? " — Transcript" : ""
                    lines[index] = "# \(safeNewTitle)\(suffix)"
                    replacedHeading = true
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func isFrontmatterTitleLine(_ line: String) -> Bool {
        line.hasPrefix("title:")
    }

    private static func isHeadingLine(_ line: String, matching title: String) -> Bool {
        guard line.hasPrefix("# ") else { return false }
        let heading = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        return heading == title || heading == FilenameSanitizer.sanitizeTitle(title)
    }
}
