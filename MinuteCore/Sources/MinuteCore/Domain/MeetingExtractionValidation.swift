import Foundation

public enum MeetingExtractionValidation {
    /// Returns a sanitized/normalized extraction, applying v1 schema rules that are easier to enforce
    /// outside the model.
    public static func validated(_ extraction: MeetingExtraction, recordingDate: Date) -> MeetingExtraction {
        var copy = extraction

        // Title: normalize to a single line; never allow empty.
        copy.title = normalizeInline(copy.title)
        if copy.title.isEmpty {
            copy.title = "Untitled"
        }

        // Date: must match YYYY-MM-DD; otherwise replace with the recording date.
        let date = normalizeInline(copy.date)
        if isValidISODate(date) {
            copy.date = date
        } else {
            copy.date = MeetingFileContract.isoDate(recordingDate)
        }

        // Summary: normalize line endings and trim.
        copy.summary = normalizeParagraph(copy.summary)

        // Arrays: normalize items.
        copy.decisions = copy.decisions.map(normalizeInline).filter { !$0.isEmpty }
        copy.openQuestions = copy.openQuestions.map(normalizeInline).filter { !$0.isEmpty }
        copy.keyPoints = copy.keyPoints.map(normalizeInline).filter { !$0.isEmpty }

        copy.actionItems = copy.actionItems
            .map { ActionItem(owner: normalizeInline($0.owner), task: normalizeInline($0.task)) }
            .filter { !$0.owner.isEmpty || !$0.task.isEmpty }

        return copy
    }

    /// Fallback extraction used when JSON cannot be decoded even after repair.
    public static func fallback(recordingDate: Date) -> MeetingExtraction {
        let iso = MeetingFileContract.isoDate(recordingDate)
        return MeetingExtraction(
            title: "Untitled",
            date: iso,
            summary: "Failed to structure output; see audio for details.",
            decisions: [],
            actionItems: [],
            openQuestions: [],
            keyPoints: []
        )
    }

    // MARK: - Helpers

    private static func isValidISODate(_ value: String) -> Bool {
        // YYYY-MM-DD
        let pattern = /^\d{4}-\d{2}-\d{2}$/
        return value.wholeMatch(of: pattern) != nil
    }

    private static func normalizeParagraph(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeInline(_ value: String) -> String {
        // Normalize to a single-line, trimmed string.
        normalizeParagraph(value)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
