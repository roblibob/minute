import Foundation

public struct MeetingParticipantFrontmatter: Sendable, Equatable, Codable {
    public var participants: [String]
    public var speakerMap: [Int: String]

    /// Optional deterministic ordering of speakers for serialization.
    /// If provided, it will be used when emitting `speaker_map` entries.
    public var speakerOrder: [Int]?

    public init(
        participants: [String],
        speakerMap: [Int: String],
        speakerOrder: [Int]? = nil
    ) {
        self.participants = participants
        self.speakerMap = speakerMap
        self.speakerOrder = speakerOrder
    }
}
