import Foundation
import Testing
@testable import MinuteCore

struct MeetingSpeakerEmbeddingCacheTests {
    @Test
    func upsertAndGet_isDeterministicAndAtomic() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let storeURL = root.appendingPathComponent("meeting_speaker_embeddings.json")
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

        let cache = MeetingSpeakerEmbeddingCache(
            config: .init(storeURL: storeURL, schemaVersion: 1, maxMeetings: 30, maxAge: TimeInterval(60 * 60 * 24)),
            now: { fixedNow }
        )

        let meetingKey = "Meetings/2026/02/2026-02-07 10.00 - Test.md"
        let embeddings: [Int: [Float]] = [
            0: unitEmbedding(index: 0),
            2: unitEmbedding(index: 2)
        ]

        #expect(try await cache.get(meetingKey: meetingKey) == nil)

        try await cache.upsert(
            meetingKey: meetingKey,
            embeddingsBySpeakerID: embeddings,
            embeddingModelVersion: SpeakerEmbeddingModelVersions.fluidAudioOfflineVbx256
        )

        #expect(FileManager.default.fileExists(atPath: storeURL.path))

        let loaded = try await cache.get(meetingKey: meetingKey)
        #expect(loaded?.meetingKey == meetingKey)
        #expect(loaded?.embeddingModelVersion == SpeakerEmbeddingModelVersions.fluidAudioOfflineVbx256)
        #expect(loaded?.embeddingsBySpeakerID.keys.sorted() == [0, 2])
        #expect(loaded?.embeddingsBySpeakerID[0] == embeddings[0])

        // JSON contains schemaVersion and meetingKey.
        let raw = try String(contentsOf: storeURL, encoding: .utf8)
        #expect(raw.contains("\"schemaVersion\""))
        #expect(raw.contains(meetingKey))
    }

    @Test
    func prune_respectsMaxMeetingsAndAge() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let storeURL = root.appendingPathComponent("meeting_speaker_embeddings.json")
        let clock = ThreadSafeClock(Date(timeIntervalSince1970: 1_700_000_000))

        let cache = MeetingSpeakerEmbeddingCache(
            config: .init(storeURL: storeURL, schemaVersion: 1, maxMeetings: 2, maxAge: 60),
            now: { clock.now() }
        )

        func upsert(_ key: String, advance: TimeInterval) async throws {
            clock.advance(by: advance)
            try await cache.upsert(
                meetingKey: key,
                embeddingsBySpeakerID: [0: unitEmbedding(index: 0)],
                embeddingModelVersion: "v1"
            )
        }

        try await upsert("a", advance: 0)
        try await upsert("b", advance: 1)
        try await upsert("c", advance: 1)

        // Max meetings = 2, keep most recent (c, b)
        #expect(try await cache.get(meetingKey: "a") == nil)
        #expect(try await cache.get(meetingKey: "b") != nil)
        #expect(try await cache.get(meetingKey: "c") != nil)

        // Advance past age cutoff; next upsert prunes old entries.
        clock.advance(by: 120)
        try await cache.upsert(
            meetingKey: "d",
            embeddingsBySpeakerID: [0: unitEmbedding(index: 0)],
            embeddingModelVersion: "v1"
        )

        #expect(try await cache.get(meetingKey: "b") == nil)
        #expect(try await cache.get(meetingKey: "c") == nil)
        #expect(try await cache.get(meetingKey: "d") != nil)
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
        .appendingPathComponent("minute-meeting-embeddings-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func unitEmbedding(index: Int) -> [Float] {
    var values = Array(repeating: Float(0), count: SpeakerProfile.embeddingDimension)
    values[index] = 1
    return values
}
