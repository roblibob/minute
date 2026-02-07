import Foundation

public enum SpeakerProfileEnrollmentAvailability: Sendable, Equatable {
    case available
    case missingMeetingEmbeddings
    case missingSpeakerEmbedding
}

public struct SpeakerProfileEnrollmentPolicy: Sendable {
    private let cache: MeetingSpeakerEmbeddingCache

    public init(cache: MeetingSpeakerEmbeddingCache = MeetingSpeakerEmbeddingCache()) {
        self.cache = cache
    }

    public func availability(meetingKey: String, speakerID: Int) async -> SpeakerProfileEnrollmentAvailability {
        do {
            guard let meeting = try await cache.get(meetingKey: meetingKey) else {
                return .missingMeetingEmbeddings
            }
            guard meeting.embeddingsBySpeakerID[speakerID] != nil else {
                return .missingSpeakerEmbedding
            }
            return .available
        } catch {
            // If the cache is unreadable for any reason, treat it as missing.
            return .missingMeetingEmbeddings
        }
    }
}
