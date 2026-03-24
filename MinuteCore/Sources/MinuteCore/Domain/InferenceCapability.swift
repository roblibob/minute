import Foundation

public enum InferenceCapability: String, CaseIterable, Sendable, Codable {
    case summarization
    case vision

    public var displayName: String {
        switch self {
        case .summarization:
            return "Summarization"
        case .vision:
            return "Vision"
        }
    }
}
