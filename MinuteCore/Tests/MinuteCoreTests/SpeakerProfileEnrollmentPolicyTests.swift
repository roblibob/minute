import Foundation
import Testing
@testable import MinuteCore

struct SpeakerProfileEnrollmentPolicyTests {
    @Test
    func availability_whenMeetingMissing_returnsMissingMeetingEmbeddings() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = MeetingSpeakerEmbeddingCache(
            config: .init(storeURL: root.appendingPathComponent("meeting_speaker_embeddings.json"))
        )
        let policy = SpeakerProfileEnrollmentPolicy(cache: cache)

        let result = await policy.availability(meetingKey: "missing", speakerID: 0)
        #expect(result == .missingMeetingEmbeddings)
    }

    @Test
    func availability_whenSpeakerMissing_returnsMissingSpeakerEmbedding() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = MeetingSpeakerEmbeddingCache(
            config: .init(storeURL: root.appendingPathComponent("meeting_speaker_embeddings.json")),
            now: { fixedNow }
        )
        let policy = SpeakerProfileEnrollmentPolicy(cache: cache)

        try await cache.upsert(
            meetingKey: "m1",
            embeddingsBySpeakerID: [0: unitEmbedding(index: 0)],
            embeddingModelVersion: SpeakerEmbeddingModelVersions.fluidAudioOfflineVbx256
        )

        let result = await policy.availability(meetingKey: "m1", speakerID: 2)
        #expect(result == .missingSpeakerEmbedding)
    }

    @Test
    func availability_whenPresent_returnsAvailable() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = MeetingSpeakerEmbeddingCache(
            config: .init(storeURL: root.appendingPathComponent("meeting_speaker_embeddings.json")),
            now: { fixedNow }
        )
        let policy = SpeakerProfileEnrollmentPolicy(cache: cache)

        try await cache.upsert(
            meetingKey: "m1",
            embeddingsBySpeakerID: [0: unitEmbedding(index: 0), 1: unitEmbedding(index: 1)],
            embeddingModelVersion: SpeakerEmbeddingModelVersions.fluidAudioOfflineVbx256
        )

        let result = await policy.availability(meetingKey: "m1", speakerID: 1)
        #expect(result == .available)
    }
}

private func makeTempDir() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-enrollment-policy-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func unitEmbedding(index: Int) -> [Float] {
    var values = Array(repeating: Float(0), count: SpeakerProfile.embeddingDimension)
    values[index] = 1
    return values
}
