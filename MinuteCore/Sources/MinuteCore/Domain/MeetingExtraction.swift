import Foundation

public struct MeetingSummarySectionVisibility: Equatable, Sendable {
    public var decisions: Bool
    public var actionItems: Bool
    public var openQuestions: Bool
    public var keyPoints: Bool

    public init(
        decisions: Bool = true,
        actionItems: Bool = true,
        openQuestions: Bool = true,
        keyPoints: Bool = true
    ) {
        self.decisions = decisions
        self.actionItems = actionItems
        self.openQuestions = openQuestions
        self.keyPoints = keyPoints
    }

    public static let allEnabled = MeetingSummarySectionVisibility()
}

/// A meeting participant identified from the transcript.
public struct MeetingParticipant: Codable, Equatable, Sendable {
    public var name: String
    /// Role or relationship (e.g. "Manager", "Presenter"). Optional.
    public var role: String?
    /// Transcript speaker label this participant maps to (e.g. "Speaker 1"). Optional.
    public var speaker: String?
    /// Evidence-based description: what they did or said, role signals, and the
    /// evidence/confidence for the name mapping. Optional.
    public var details: String?

    public init(name: String, role: String? = nil, speaker: String? = nil, details: String? = nil) {
        self.name = name
        self.role = role
        self.speaker = speaker
        self.details = details
    }
}

/// A distinct topic discussed in the meeting, with detail points.
public struct MeetingTopic: Codable, Equatable, Sendable {
    public var title: String
    public var points: [String]

    public init(title: String, points: [String] = []) {
        self.title = title
        self.points = points
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case points
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        points = try container.decodeIfPresent([String].self, forKey: .points) ?? []
    }
}

/// Fixed v1 schema produced by the summarization model.
///
/// The model must output JSON only, matching this structure exactly.
/// `participants` and `topics` are optional enrichments — capable models fill
/// them; models that omit them produce the original layout.
public struct MeetingExtraction: Codable, Equatable, Sendable {
    public var title: String
    /// `YYYY-MM-DD`
    public var date: String
    public var summary: String
    public var decisions: [String]
    public var actionItems: [ActionItem]
    public var openQuestions: [String]
    public var keyPoints: [String]
    public var participants: [MeetingParticipant]
    public var topics: [MeetingTopic]
    public var meetingType: MeetingType?

    public init(
        title: String,
        date: String,
        summary: String,
        decisions: [String] = [],
        actionItems: [ActionItem] = [],
        openQuestions: [String] = [],
        keyPoints: [String] = [],
        participants: [MeetingParticipant] = [],
        topics: [MeetingTopic] = [],
        meetingType: MeetingType? = nil
    ) {
        self.title = title
        self.date = date
        self.summary = summary
        self.decisions = decisions
        self.actionItems = actionItems
        self.openQuestions = openQuestions
        self.keyPoints = keyPoints
        self.participants = participants
        self.topics = topics
        self.meetingType = meetingType
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case date
        case summary
        case decisions
        case actionItems = "action_items"
        case openQuestions = "open_questions"
        case keyPoints = "key_points"
        case participants
        case topics
        case meetingType = "meeting_type"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(String.self, forKey: .date)
        summary = try container.decode(String.self, forKey: .summary)
        decisions = try container.decodeIfPresent([String].self, forKey: .decisions) ?? []
        actionItems = try container.decodeIfPresent([ActionItem].self, forKey: .actionItems) ?? []
        openQuestions = try container.decodeIfPresent([String].self, forKey: .openQuestions) ?? []
        keyPoints = try container.decodeIfPresent([String].self, forKey: .keyPoints) ?? []
        participants = try container.decodeIfPresent([MeetingParticipant].self, forKey: .participants) ?? []
        topics = try container.decodeIfPresent([MeetingTopic].self, forKey: .topics) ?? []
        meetingType = try container.decodeIfPresent(MeetingType.self, forKey: .meetingType)
    }
}

public struct ActionItem: Codable, Equatable, Sendable {
    public var owner: String
    public var task: String
    /// `YYYY-MM-DD` or "TBD". Optional table field.
    public var dueDate: String?
    /// E.g. "Not Started". Optional table field.
    public var status: String?
    /// Supporting context. Optional table field.
    public var comments: String?

    public init(
        owner: String,
        task: String,
        dueDate: String? = nil,
        status: String? = nil,
        comments: String? = nil
    ) {
        self.owner = owner
        self.task = task
        self.dueDate = dueDate
        self.status = status
        self.comments = comments
    }

    private enum CodingKeys: String, CodingKey {
        case owner
        case task
        case dueDate = "due_date"
        case status
        case comments
    }

    /// True when any optional table column is populated.
    public var hasTableFields: Bool {
        [dueDate, status, comments].contains { field in
            guard let field else { return false }
            return !field.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

public struct SummarizationPassDelta: Codable, Equatable, Sendable {
    public var title: String
    public var date: String
    public var summaryPoints: [String]
    public var decisions: [String]
    public var actionItems: [ActionItem]
    public var openQuestions: [String]
    public var keyPoints: [String]
    public var participants: [MeetingParticipant]
    public var topics: [MeetingTopic]

    public init(
        title: String = "",
        date: String = "",
        summaryPoints: [String] = [],
        decisions: [String] = [],
        actionItems: [ActionItem] = [],
        openQuestions: [String] = [],
        keyPoints: [String] = [],
        participants: [MeetingParticipant] = [],
        topics: [MeetingTopic] = []
    ) {
        self.title = title
        self.date = date
        self.summaryPoints = summaryPoints
        self.decisions = decisions
        self.actionItems = actionItems
        self.openQuestions = openQuestions
        self.keyPoints = keyPoints
        self.participants = participants
        self.topics = topics
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case date
        case summary
        case summaryPoints = "summary_points"
        case decisions
        case actionItems = "action_items"
        case openQuestions = "open_questions"
        case keyPoints = "key_points"
        case participants
        case topics
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        date = try container.decodeIfPresent(String.self, forKey: .date) ?? ""
        let explicitSummaryPoints = try container.decodeIfPresent([String].self, forKey: .summaryPoints) ?? []
        let legacySummary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        summaryPoints = explicitSummaryPoints.isEmpty ? Self.summaryPoints(from: legacySummary) : explicitSummaryPoints
        decisions = try container.decodeIfPresent([String].self, forKey: .decisions) ?? []
        actionItems = try container.decodeIfPresent([ActionItem].self, forKey: .actionItems) ?? []
        openQuestions = try container.decodeIfPresent([String].self, forKey: .openQuestions) ?? []
        keyPoints = try container.decodeIfPresent([String].self, forKey: .keyPoints) ?? []
        participants = try container.decodeIfPresent([MeetingParticipant].self, forKey: .participants) ?? []
        topics = try container.decodeIfPresent([MeetingTopic].self, forKey: .topics) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(date, forKey: .date)
        try container.encode(summaryPoints, forKey: .summaryPoints)
        try container.encode(decisions, forKey: .decisions)
        try container.encode(actionItems, forKey: .actionItems)
        try container.encode(openQuestions, forKey: .openQuestions)
        try container.encode(keyPoints, forKey: .keyPoints)
        try container.encode(participants, forKey: .participants)
        try container.encode(topics, forKey: .topics)
    }

    public static func summaryPoints(from summary: String) -> [String] {
        let normalized = StringNormalizer.normalizeParagraph(summary)
        guard !normalized.isEmpty else { return [] }
        return [normalized]
    }
}

public struct SummarizationMergeState: Codable, Equatable, Sendable {
    public var title: String
    public var date: String
    public var summaryPoints: [String]
    public var decisions: [String]
    public var actionItems: [ActionItem]
    public var openQuestions: [String]
    public var keyPoints: [String]
    public var participants: [MeetingParticipant]
    public var topics: [MeetingTopic]
    public var meetingType: MeetingType?

    public init(
        title: String = "",
        date: String = "",
        summaryPoints: [String] = [],
        decisions: [String] = [],
        actionItems: [ActionItem] = [],
        openQuestions: [String] = [],
        keyPoints: [String] = [],
        participants: [MeetingParticipant] = [],
        topics: [MeetingTopic] = [],
        meetingType: MeetingType? = nil
    ) {
        self.title = title
        self.date = date
        self.summaryPoints = summaryPoints
        self.decisions = decisions
        self.actionItems = actionItems
        self.openQuestions = openQuestions
        self.keyPoints = keyPoints
        self.participants = participants
        self.topics = topics
        self.meetingType = meetingType
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case date
        case summaryPoints
        case decisions
        case actionItems
        case openQuestions
        case keyPoints
        case participants
        case topics
        case meetingType
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        date = try container.decodeIfPresent(String.self, forKey: .date) ?? ""
        summaryPoints = try container.decodeIfPresent([String].self, forKey: .summaryPoints) ?? []
        decisions = try container.decodeIfPresent([String].self, forKey: .decisions) ?? []
        actionItems = try container.decodeIfPresent([ActionItem].self, forKey: .actionItems) ?? []
        openQuestions = try container.decodeIfPresent([String].self, forKey: .openQuestions) ?? []
        keyPoints = try container.decodeIfPresent([String].self, forKey: .keyPoints) ?? []
        participants = try container.decodeIfPresent([MeetingParticipant].self, forKey: .participants) ?? []
        topics = try container.decodeIfPresent([MeetingTopic].self, forKey: .topics) ?? []
        meetingType = try container.decodeIfPresent(MeetingType.self, forKey: .meetingType)
    }

    public init(extraction: MeetingExtraction) {
        self.init(
            title: extraction.title,
            date: extraction.date,
            summaryPoints: SummarizationPassDelta.summaryPoints(from: extraction.summary),
            decisions: extraction.decisions,
            actionItems: extraction.actionItems,
            openQuestions: extraction.openQuestions,
            keyPoints: extraction.keyPoints,
            participants: extraction.participants,
            topics: extraction.topics,
            meetingType: extraction.meetingType
        )
    }
}
