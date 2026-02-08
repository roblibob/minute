import Foundation
import Testing
@testable import MinuteCore

struct SpeakerProfileEnrollmentServiceTests {
    @Test
    func createProfileFromMeeting_isDeterministic() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

        let cache = MeetingSpeakerEmbeddingCache(
            config: .init(storeURL: root.appendingPathComponent("meeting_speaker_embeddings.json")),
            now: { fixedNow }
        )
        let store = SpeakerProfileStore(
            config: .init(storeURL: root.appendingPathComponent("speaker_profiles.json")),
            now: { fixedNow },
            idGenerator: { "fixed-id" }
        )

        try await cache.upsert(
            meetingKey: "meeting",
            embeddingsBySpeakerID: [0: unitEmbedding(index: 0)],
            embeddingModelVersion: SpeakerEmbeddingModelVersions.fluidAudioOfflineVbx256
        )

        let service = SpeakerProfileEnrollmentService(cache: cache, store: store)
        let profile = try await service.createProfileFromMeeting(meetingKey: "meeting", speakerID: 0, name: "Alice")

        #expect(profile.id == "fixed-id")
        #expect(profile.name == "Alice")
        #expect(profile.embeddingModelVersion == SpeakerEmbeddingModelVersions.fluidAudioOfflineVbx256)
        #expect(profile.embeddings == [unitEmbedding(index: 0)])
        #expect(profile.createdAt == fixedNow)
        #expect(profile.updatedAt == fixedNow)

        let listed = try await store.listProfiles()
        #expect(listed.count == 1)
        #expect(listed.first == profile)
    }

    @Test
    func updateProfileFromMeeting_appendsEmbeddingDeterministically() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let clock = ThreadSafeClock(Date(timeIntervalSince1970: 1_700_000_000))

        let cache = MeetingSpeakerEmbeddingCache(
            config: .init(storeURL: root.appendingPathComponent("meeting_speaker_embeddings.json")),
            now: { clock.now() }
        )
        let store = SpeakerProfileStore(
            config: .init(storeURL: root.appendingPathComponent("speaker_profiles.json")),
            now: { clock.now() },
            idGenerator: { "p1" }
        )

        try await cache.upsert(
            meetingKey: "meeting",
            embeddingsBySpeakerID: [0: unitEmbedding(index: 0)],
            embeddingModelVersion: SpeakerEmbeddingModelVersions.fluidAudioOfflineVbx256
        )

        let service = SpeakerProfileEnrollmentService(cache: cache, store: store)
        let created = try await service.createProfileFromMeeting(meetingKey: "meeting", speakerID: 0, name: "Alice")

        clock.advance(by: 10)
        try await cache.upsert(
            meetingKey: "meeting",
            embeddingsBySpeakerID: [0: unitEmbedding(index: 1)],
            embeddingModelVersion: SpeakerEmbeddingModelVersions.fluidAudioOfflineVbx256
        )

        let updated = try await service.updateProfileFromMeeting(meetingKey: "meeting", speakerID: 0, profileID: created.id)
        #expect(updated.id == created.id)
        #expect(updated.name == "Alice")
        #expect(updated.embeddings == [unitEmbedding(index: 0), unitEmbedding(index: 1)])
        #expect(updated.updatedAt == clock.now())

        let listed = try await store.listProfiles()
        #expect(listed.count == 1)
        #expect(listed.first?.embeddings == [unitEmbedding(index: 0), unitEmbedding(index: 1)])
    }

    @Test
    func createProfileFromMeeting_whenNameExists_appendsToSameProfile() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let clock = ThreadSafeClock(Date(timeIntervalSince1970: 1_700_000_000))

        let cache = MeetingSpeakerEmbeddingCache(
            config: .init(storeURL: root.appendingPathComponent("meeting_speaker_embeddings.json")),
            now: { clock.now() }
        )
        let store = SpeakerProfileStore(
            config: .init(storeURL: root.appendingPathComponent("speaker_profiles.json")),
            now: { clock.now() },
            idGenerator: { "p1" }
        )

        try await cache.upsert(
            meetingKey: "meeting",
            embeddingsBySpeakerID: [0: unitEmbedding(index: 0)],
            embeddingModelVersion: SpeakerEmbeddingModelVersions.fluidAudioOfflineVbx256
        )

        let service = SpeakerProfileEnrollmentService(cache: cache, store: store)
        let first = try await service.createProfileFromMeeting(meetingKey: "meeting", speakerID: 0, name: "Alice")
        #expect(first.id == "p1")
        #expect(first.embeddings == [unitEmbedding(index: 0)])

        clock.advance(by: 10)
        try await cache.upsert(
            meetingKey: "meeting",
            embeddingsBySpeakerID: [0: unitEmbedding(index: 1)],
            embeddingModelVersion: SpeakerEmbeddingModelVersions.fluidAudioOfflineVbx256
        )

        let second = try await service.createProfileFromMeeting(meetingKey: "meeting", speakerID: 0, name: "Alice")
        #expect(second.id == "p1")
        #expect(second.embeddings == [unitEmbedding(index: 0), unitEmbedding(index: 1)])

        let listed = try await store.listProfiles()
        #expect(listed.count == 1)
        #expect(listed.first?.id == "p1")
        #expect(listed.first?.embeddings == [unitEmbedding(index: 0), unitEmbedding(index: 1)])
    }

    @Test
    func createProfileFromMeeting_whenMissing_throwsEmbeddingsUnavailable() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = MeetingSpeakerEmbeddingCache(
            config: .init(storeURL: root.appendingPathComponent("meeting_speaker_embeddings.json"))
        )
        let store = SpeakerProfileStore(
            config: .init(storeURL: root.appendingPathComponent("speaker_profiles.json")),
            idGenerator: { "p1" }
        )
        let service = SpeakerProfileEnrollmentService(cache: cache, store: store)

        await #expect(throws: SpeakerProfileEnrollmentError.embeddingsUnavailable) {
            _ = try await service.createProfileFromMeeting(meetingKey: "missing", speakerID: 0, name: "Alice")
        }
    }
}

private final class ThreadSafeClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(_ value: Date) {
        self.value = value
    }

    func now() -> Date {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    func advance(by seconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        value = value.addingTimeInterval(seconds)
    }
}

private func makeTempDir() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-enrollment-service-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func unitEmbedding(index: Int) -> [Float] {
    var values = Array(repeating: Float(0), count: SpeakerProfile.embeddingDimension)
    values[index] = 1
    return values
}
