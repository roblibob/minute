import Foundation

public enum SpeakerProfileEnrollmentError: Error, LocalizedError, Sendable, Equatable {
    case embeddingsUnavailable
    case speakerEmbeddingUnavailable

    public var errorDescription: String? {
        switch self {
        case .embeddingsUnavailable:
            return "Embeddings for this meeting aren’t available. Reprocess the meeting with Known Speaker Suggestions enabled, then try again."
        case .speakerEmbeddingUnavailable:
            return "Embeddings for this speaker aren’t available. Reprocess the meeting and try again."
        }
    }
}

public struct SpeakerProfileEnrollmentService: Sendable {
    private let cache: MeetingSpeakerEmbeddingCache
    private let store: SpeakerProfileStore

    public init(
        cache: MeetingSpeakerEmbeddingCache = MeetingSpeakerEmbeddingCache(),
        store: SpeakerProfileStore = SpeakerProfileStore()
    ) {
        self.cache = cache
        self.store = store
    }

    public func createProfileFromMeeting(meetingKey: String, speakerID: Int, name: String, isPermanent: Bool = false) async throws -> SpeakerProfile {
        let embedding = try await loadEmbedding(meetingKey: meetingKey, speakerID: speakerID)
        return try await store.createProfile(
            name: name,
            embedding: embedding,
            embeddingModelVersion: SpeakerEmbeddingModelVersions.fluidAudioOfflineVbx256,
            isPermanent: isPermanent
        )
    }

    public func updateProfileFromMeeting(meetingKey: String, speakerID: Int, profileID: String) async throws -> SpeakerProfile {
        let embedding = try await loadEmbedding(meetingKey: meetingKey, speakerID: speakerID)
        return try await store.updateProfileEmbedding(
            profileID: profileID,
            embedding: embedding,
            embeddingModelVersion: SpeakerEmbeddingModelVersions.fluidAudioOfflineVbx256
        )
    }

    private func loadEmbedding(meetingKey: String, speakerID: Int) async throws -> [Float] {
        guard let meeting = try await cache.get(meetingKey: meetingKey) else {
            throw SpeakerProfileEnrollmentError.embeddingsUnavailable
        }
        guard let embedding = meeting.embeddingsBySpeakerID[speakerID] else {
            throw SpeakerProfileEnrollmentError.speakerEmbeddingUnavailable
        }
        return embedding
    }
}
