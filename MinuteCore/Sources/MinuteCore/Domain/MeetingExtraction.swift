import Foundation

/// Fixed v1 schema produced by the summarization model.
///
/// The model must output JSON only, matching this structure exactly.
public struct MeetingExtraction: Codable, Equatable, Sendable {
    public var title: String
    /// `YYYY-MM-DD`
    public var date: String
    public var summary: String
    public var decisions: [String]
    public var actionItems: [ActionItem]
    public var openQuestions: [String]
    public var keyPoints: [String]

    public init(
        title: String,
        date: String,
        summary: String,
        decisions: [String],
        actionItems: [ActionItem],
        openQuestions: [String],
        keyPoints: [String]
    ) {
        self.title = title
        self.date = date
        self.summary = summary
        self.decisions = decisions
        self.actionItems = actionItems
        self.openQuestions = openQuestions
        self.keyPoints = keyPoints
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case date
        case summary
        case decisions
        case actionItems = "action_items"
        case openQuestions = "open_questions"
        case keyPoints = "key_points"
    }
}

public struct ActionItem: Codable, Equatable, Sendable {
    public var owner: String
    public var task: String

    public init(owner: String, task: String) {
        self.owner = owner
        self.task = task
    }
}
