import Foundation

public enum MeetingType: String, CaseIterable, Codable, Sendable {
    case general
    case standup
    case designReview = "design_review"
    case oneOnOne = "one_on_one"
    case presentation
    case planning
    case autodetect
}
