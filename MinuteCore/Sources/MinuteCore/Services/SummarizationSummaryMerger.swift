import Foundation

public enum SummarizationSummaryMerger {
    private static let normalizationLocale = Locale(identifier: "en_US_POSIX")

    public static func merge(
        previousState: SummarizationMergeState?,
        delta: SummarizationPassDelta,
        meetingType: MeetingType?,
        recordingDate: Date
    ) -> SummarizationMergeState {
        let previous = previousState ?? SummarizationMergeState()

        return SummarizationMergeState(
            title: preferredTitle(previous: previous.title, next: delta.title),
            date: preferredDate(previous: previous.date, next: delta.date, recordingDate: recordingDate),
            summaryPoints: mergeStrings(previous.summaryPoints, delta.summaryPoints),
            decisions: mergeStrings(previous.decisions, delta.decisions),
            actionItems: mergeActionItems(previous.actionItems, delta.actionItems),
            openQuestions: mergeStrings(previous.openQuestions, delta.openQuestions),
            keyPoints: mergeStrings(previous.keyPoints, delta.keyPoints),
            participants: mergeParticipants(previous.participants, delta.participants),
            topics: mergeTopics(previous.topics, delta.topics),
            meetingType: meetingType ?? previous.meetingType
        )
    }

    public static func extraction(
        from state: SummarizationMergeState,
        recordingDate: Date
    ) -> MeetingExtraction {
        let extraction = MeetingExtraction(
            title: state.title,
            date: state.date,
            summary: renderSummary(from: state.summaryPoints),
            decisions: state.decisions,
            actionItems: state.actionItems,
            openQuestions: state.openQuestions,
            keyPoints: state.keyPoints,
            participants: state.participants,
            topics: state.topics,
            meetingType: state.meetingType
        )
        return MeetingExtractionValidation.validated(extraction, recordingDate: recordingDate)
    }

    private static func preferredTitle(previous: String, next: String) -> String {
        let normalizedNext = StringNormalizer.normalizeTitle(next)
        if !normalizedNext.isEmpty, normalizedNext != "Untitled" {
            return normalizedNext
        }

        let normalizedPrevious = StringNormalizer.normalizeTitle(previous)
        return normalizedPrevious
    }

    private static func preferredDate(previous: String, next: String, recordingDate: Date) -> String {
        let nextDate = StringNormalizer.normalizeInline(next)
        if isValidISODate(nextDate) {
            return nextDate
        }

        let previousDate = StringNormalizer.normalizeInline(previous)
        if isValidISODate(previousDate) {
            return previousDate
        }

        return MeetingFileContract.isoDate(recordingDate)
    }

    private static func renderSummary(from points: [String]) -> String {
        mergeStrings([], points).joined(separator: "\n\n")
    }

    private static func mergeStrings(_ previous: [String], _ next: [String]) -> [String] {
        var merged = previous
            .map(StringNormalizer.normalizeParagraph)
            .filter { !$0.isEmpty }

        for rawCandidate in next {
            let candidate = StringNormalizer.normalizeParagraph(rawCandidate)
            guard !candidate.isEmpty else { continue }

            if let index = merged.firstIndex(where: { overlaps($0, candidate) }) {
                merged[index] = preferredValue(existing: merged[index], incoming: candidate)
            } else {
                merged.append(candidate)
            }
        }

        return merged
    }

    private static func mergeActionItems(_ previous: [ActionItem], _ next: [ActionItem]) -> [ActionItem] {
        var merged = previous
            .map { normalizedActionItem($0) }
            .filter { !$0.owner.isEmpty || !$0.task.isEmpty }

        for candidate in next {
            let normalized = normalizedActionItem(candidate)
            guard !normalized.owner.isEmpty || !normalized.task.isEmpty else { continue }

            if let index = merged.firstIndex(where: { overlaps($0, normalized) }) {
                merged[index] = preferredActionItem(existing: merged[index], incoming: normalized)
            } else {
                merged.append(normalized)
            }
        }

        return merged
    }

    private static func normalizedActionItem(_ item: ActionItem) -> ActionItem {
        ActionItem(
            owner: StringNormalizer.normalizeInline(item.owner),
            task: StringNormalizer.normalizeInline(item.task),
            dueDate: normalizedOptionalField(item.dueDate),
            status: normalizedOptionalField(item.status),
            comments: normalizedOptionalField(item.comments)
        )
    }

    private static func normalizedOptionalField(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = StringNormalizer.normalizeInline(value)
        return normalized.isEmpty ? nil : normalized
    }

    private static func mergeParticipants(
        _ previous: [MeetingParticipant],
        _ next: [MeetingParticipant]
    ) -> [MeetingParticipant] {
        var merged = previous
            .map { normalizedParticipant($0) }
            .filter { !$0.name.isEmpty }

        for candidate in next {
            let normalized = normalizedParticipant(candidate)
            guard !normalized.name.isEmpty else { continue }

            if let index = merged.firstIndex(where: { normalizedKey($0.name) == normalizedKey(normalized.name) }) {
                merged[index].role = mergedOptionalField(existing: merged[index].role, incoming: normalized.role)
                merged[index].speaker = merged[index].speaker ?? normalized.speaker
                merged[index].details = mergedOptionalField(existing: merged[index].details, incoming: normalized.details)
            } else {
                merged.append(normalized)
            }
        }

        return merged
    }

    private static func normalizedParticipant(_ participant: MeetingParticipant) -> MeetingParticipant {
        MeetingParticipant(
            name: StringNormalizer.normalizeInline(participant.name),
            role: normalizedOptionalField(participant.role),
            speaker: normalizedOptionalField(participant.speaker),
            details: normalizedOptionalField(participant.details)
        )
    }

    /// Backfills a nil field or prefers the richer of two values.
    private static func mergedOptionalField(existing: String?, incoming: String?) -> String? {
        switch (existing, incoming) {
        case (nil, let incoming):
            return incoming
        case (let existing, nil):
            return existing
        case (let existing?, let incoming?):
            return preferredValue(existing: existing, incoming: incoming)
        }
    }

    private static func mergeTopics(_ previous: [MeetingTopic], _ next: [MeetingTopic]) -> [MeetingTopic] {
        var merged = previous
            .map {
                MeetingTopic(
                    title: StringNormalizer.normalizeInline($0.title),
                    points: $0.points.map(StringNormalizer.normalizeInline).filter { !$0.isEmpty }
                )
            }
            .filter { !$0.title.isEmpty }

        for candidate in next {
            let normalized = MeetingTopic(
                title: StringNormalizer.normalizeInline(candidate.title),
                points: candidate.points.map(StringNormalizer.normalizeInline).filter { !$0.isEmpty }
            )
            guard !normalized.title.isEmpty else { continue }

            if let index = merged.firstIndex(where: { normalizedKey($0.title) == normalizedKey(normalized.title) }) {
                merged[index].points = mergeStrings(merged[index].points, normalized.points)
            } else {
                merged.append(normalized)
            }
        }

        return merged
    }

    private static func overlaps(_ lhs: String, _ rhs: String) -> Bool {
        let lhsKey = normalizedKey(lhs)
        let rhsKey = normalizedKey(rhs)

        if lhsKey == rhsKey {
            return true
        }

        return lhsKey.contains(rhsKey) || rhsKey.contains(lhsKey)
    }

    private static func preferredValue(existing: String, incoming: String) -> String {
        let existingKey = normalizedKey(existing)
        let incomingKey = normalizedKey(incoming)

        if incomingKey.contains(existingKey) && incoming.count >= existing.count {
            return incoming
        }

        if existingKey.contains(incomingKey) && existing.count >= incoming.count {
            return existing
        }

        return incoming.count > existing.count ? incoming : existing
    }

    private static func overlaps(_ lhs: ActionItem, _ rhs: ActionItem) -> Bool {
        let lhsOwner = normalizedKey(lhs.owner)
        let rhsOwner = normalizedKey(rhs.owner)
        let ownersMatch = lhsOwner == rhsOwner || lhsOwner.isEmpty || rhsOwner.isEmpty

        if !ownersMatch {
            return false
        }

        return overlaps(lhs.task, rhs.task)
    }

    private static func preferredActionItem(existing: ActionItem, incoming: ActionItem) -> ActionItem {
        let owner = preferredValue(existing: existing.owner, incoming: incoming.owner)
        let task = preferredValue(existing: existing.task, incoming: incoming.task)
        return ActionItem(owner: owner, task: task)
    }

    private static func normalizedKey(_ value: String) -> String {
        let folded = StringNormalizer.normalizeInline(value)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: normalizationLocale)

        let scalars = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }
            return " "
        }

        return String(scalars)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isValidISODate(_ value: String) -> Bool {
        let pattern = /^\d{4}-\d{2}-\d{2}$/
        return value.wholeMatch(of: pattern) != nil
    }
}
