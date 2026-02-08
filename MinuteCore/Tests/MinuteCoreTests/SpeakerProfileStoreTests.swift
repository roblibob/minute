import Foundation
import Testing
@testable import MinuteCore

struct SpeakerProfileStoreTests {
    @Test
    func storeCRUD_isDeterministicAndAtomic() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let storeURL = root.appendingPathComponent("speaker_profiles.json")
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

        let store = SpeakerProfileStore(
            config: .init(storeURL: storeURL, schemaVersion: 2),
            now: { fixedNow },
            idGenerator: { "p-1" }
        )

        #expect(try await store.listProfiles().isEmpty)

        let embedding = unitEmbedding(index: 0)
        let created = try await store.createProfile(
            name: "Alice",
            embedding: embedding,
            embeddingModelVersion: "v1",
            isPermanent: true
        )
        #expect(created.id == "p-1")
        #expect(created.name == "Alice")
        #expect(created.embeddings.count == 1)

        let afterCreate = try await store.listProfiles()
        #expect(afterCreate.map(\.id) == ["p-1"])
        #expect(FileManager.default.fileExists(atPath: storeURL.path))

        let raw = try String(contentsOf: storeURL, encoding: .utf8)
        #expect(raw.contains("\"schemaVersion\""))
        #expect(raw.contains("\"profiles\""))
        #expect(raw.contains("\"Alice\""))

        let updated = try await store.updateProfile(profileID: created.id, name: "Alice A.")
        #expect(updated.name == "Alice A.")
        #expect(updated.createdAt <= updated.updatedAt)

        try await store.deleteProfile(profileID: created.id)
        #expect(try await store.listProfiles().isEmpty)
    }

    @Test
    func matcher_bestMatch_isDeterministicAndRespectsThreshold() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let p1 = try SpeakerProfile(
            id: "a",
            name: "Alice",
            embeddings: [unitEmbedding(index: 0)],
            embeddingModelVersion: "v1",
            createdAt: now,
            updatedAt: now,
            isPermanent: false
        )
        let p2 = try SpeakerProfile(
            id: "b",
            name: "Bob",
            embeddings: [unitEmbedding(index: 1)],
            embeddingModelVersion: "v1",
            createdAt: now,
            updatedAt: now,
            isPermanent: false
        )

        let matcher = SpeakerEmbeddingMatcher()

        let match1 = try matcher.bestMatch(
            embedding: unitEmbedding(index: 0),
            candidates: [p2, p1],
            embeddingModelVersion: "v1",
            thresholds: .init(minCosineSimilarity: 0.75)
        )
        #expect(match1?.profile.id == "a")

        let noMatch = try matcher.bestMatch(
            embedding: unitEmbedding(index: 0),
            candidates: [p1],
            embeddingModelVersion: "v1",
            thresholds: .init(minCosineSimilarity: 1.00001)
        )
        #expect(noMatch == nil)

        // Tie-break is deterministic by profile id.
        let p3 = try SpeakerProfile(
            id: "0",
            name: "Alt",
            embeddings: [unitEmbedding(index: 0)],
            embeddingModelVersion: "v1",
            createdAt: now,
            updatedAt: now,
            isPermanent: false
        )
        let tie = try matcher.bestMatch(
            embedding: unitEmbedding(index: 0),
            candidates: [p1, p3],
            embeddingModelVersion: "v1",
            thresholds: .init(minCosineSimilarity: 0.75)
        )
        #expect(tie?.profile.id == "0")

        // Multi-embedding profiles should match against the best stored embedding.
        let p4 = try SpeakerProfile(
            id: "c",
            name: "Multi",
            embeddings: [unitEmbedding(index: 2), unitEmbedding(index: 0)],
            embeddingModelVersion: "v1",
            createdAt: now,
            updatedAt: now,
            isPermanent: false
        )
        let multi = try matcher.bestMatch(
            embedding: unitEmbedding(index: 0),
            candidates: [p2, p4],
            embeddingModelVersion: "v1",
            thresholds: .init(minCosineSimilarity: 0.75)
        )
        #expect(multi?.profile.id == "c")
    }

    @Test
    func store_migratesSchemaV1ToV2() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let storeURL = root.appendingPathComponent("speaker_profiles.json")
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        struct V1Profile: Codable {
            var id: String
            var name: String
            var embedding: [Float]
            var embeddingModelVersion: String
            var createdAt: Date
            var updatedAt: Date
            var isPermanent: Bool
        }

        struct V1StoreFile: Codable {
            var schemaVersion: Int
            var profiles: [V1Profile]
        }

        let v1 = V1StoreFile(
            schemaVersion: 1,
            profiles: [
                V1Profile(
                    id: "p1",
                    name: "Alice",
                    embedding: unitEmbedding(index: 0),
                    embeddingModelVersion: "v1",
                    createdAt: now,
                    updatedAt: now,
                    isPermanent: false
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(v1)
        try data.write(to: storeURL, options: [.atomic])

        let store = SpeakerProfileStore(
            config: .init(storeURL: storeURL, schemaVersion: 2),
            now: { now },
            idGenerator: { "ignored" }
        )

        let migrated = try await store.listProfiles()
        #expect(migrated.count == 1)
        #expect(migrated.first?.id == "p1")
        #expect(migrated.first?.name == "Alice")
        #expect(migrated.first?.embeddings == [unitEmbedding(index: 0)])

        let raw = try String(contentsOf: storeURL, encoding: .utf8)
        #expect(raw.contains("\"schemaVersion\""))
        #expect(raw.contains("\"embeddings\""))
        #expect(!raw.contains("\"embedding\""))
    }
}

private func makeTempDir() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-speaker-profiles-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func unitEmbedding(index: Int) -> [Float] {
    var values = Array(repeating: Float(0), count: SpeakerProfile.embeddingDimension)
    values[index] = 1
    return values
}
