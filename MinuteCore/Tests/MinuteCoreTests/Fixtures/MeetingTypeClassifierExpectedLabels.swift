import Foundation
@testable import MinuteCore

enum MeetingTypeClassifierExpectedLabels {
    static let clearCases: [(snippet: String, expected: MeetingType)] =
        MeetingTypeClassifierSnippets.clearStandup.map { ($0, .standup) } +
        MeetingTypeClassifierSnippets.clearOneOnOne.map { ($0, .oneOnOne) } +
        MeetingTypeClassifierSnippets.clearDesignReview.map { ($0, .designReview) } +
        MeetingTypeClassifierSnippets.clearPresentation.map { ($0, .presentation) } +
        MeetingTypeClassifierSnippets.clearPlanning.map { ($0, .planning) }

    static let shouldDefaultToGeneral: [String] =
        MeetingTypeClassifierSnippets.lowInformation +
        MeetingTypeClassifierSnippets.mixedSignals +
        MeetingTypeClassifierSnippets.keywordTraps
}
