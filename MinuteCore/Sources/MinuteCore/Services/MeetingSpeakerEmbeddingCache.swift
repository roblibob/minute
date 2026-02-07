import Foundation

public enum MeetingSpeakerEmbeddingCacheError: Error, LocalizedError, Sendable, Equatable {
    case invalidStoreSchemaVersion
    case decodingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidStoreSchemaVersion:
            return "Meeting speaker embedding cache format is not supported."
        case .decodingFailed:
            return "Failed to read meeting speaker embedding cache."
        }
    }
}

public actor MeetingSpeakerEmbeddingCache {
    public struct Configuration: Sendable {
        public var storeURL: URL
        public var schemaVersion: Int
        public var maxMeetings: Int
        public var maxAge: TimeInterval

        public init(
            storeURL: URL,
            schemaVersion: Int = 1,
            maxMeetings: Int = 30,
            maxAge: TimeInterval = 60 * 60 * 24 * 14
        ) {
            self.storeURL = storeURL
            self.schemaVersion = schemaVersion
            self.maxMeetings = maxMeetings
            self.maxAge = maxAge
        }

        public static func `default`() -> Configuration {
            let applicationSupportRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")

            let storeURL = applicationSupportRoot
                .appendingPathComponent("Minute", isDirectory: true)
                .appendingPathComponent("meeting_speaker_embeddings.json")

            return Configuration(storeURL: storeURL)
        }
    }

    public struct MeetingEmbeddings: Sendable, Equatable {
        public var meetingKey: String
        public var embeddingModelVersion: String
        public var embeddingsBySpeakerID: [Int: [Float]]
        public var createdAt: Date
        public var updatedAt: Date

        public init(
            meetingKey: String,
            embeddingModelVersion: String,
            embeddingsBySpeakerID: [Int: [Float]],
            createdAt: Date,
            updatedAt: Date
        ) {
            self.meetingKey = meetingKey
            self.embeddingModelVersion = embeddingModelVersion
            self.embeddingsBySpeakerID = embeddingsBySpeakerID
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    private struct StoreFile: Codable, Sendable, Equatable {
        var schemaVersion: Int
        var meetings: [String: MeetingEntry]
    }

    private struct MeetingEntry: Codable, Sendable, Equatable {
        var embeddingModelVersion: String
        /// Keys are speaker IDs as strings to ensure stable JSON encoding.
        var embeddingsBySpeakerID: [String: [Float]]
        var createdAt: Date
        var updatedAt: Date
    }

    private let config: Configuration
    private let now: @Sendable () -> Date

    public init(
        config: Configuration = .default(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.config = config
        self.now = now
    }

    public func get(meetingKey: String) throws -> MeetingEmbeddings? {
        let store = try loadStoreFile()
        guard let entry = store.meetings[meetingKey] else { return nil }

        var decoded: [Int: [Float]] = [:]
        decoded.reserveCapacity(entry.embeddingsBySpeakerID.count)
        for (key, value) in entry.embeddingsBySpeakerID {
            guard let speakerID = Int(key) else { continue }
            decoded[speakerID] = value
        }

        return MeetingEmbeddings(
            meetingKey: meetingKey,
            embeddingModelVersion: entry.embeddingModelVersion,
            embeddingsBySpeakerID: decoded,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt
        )
    }

    public func hasEmbeddings(meetingKey: String) throws -> Bool {
        let store = try loadStoreFile()
        return store.meetings[meetingKey] != nil
    }

    public func upsert(
        meetingKey: String,
        embeddingsBySpeakerID: [Int: [Float]],
        embeddingModelVersion: String
    ) throws {
        var store = try loadStoreFile()
        let timestamp = now()

        var encodedEmbeddings: [String: [Float]] = [:]
        encodedEmbeddings.reserveCapacity(embeddingsBySpeakerID.count)
        for (speakerID, embedding) in embeddingsBySpeakerID {
            encodedEmbeddings[String(speakerID)] = embedding
        }

        let createdAt = store.meetings[meetingKey]?.createdAt ?? timestamp
        store.meetings[meetingKey] = MeetingEntry(
            embeddingModelVersion: embeddingModelVersion,
            embeddingsBySpeakerID: encodedEmbeddings,
            createdAt: createdAt,
            updatedAt: timestamp
        )

        store = prune(store)
        try saveStoreFile(store)
    }

    public func delete(meetingKey: String) throws {
        var store = try loadStoreFile()
        store.meetings.removeValue(forKey: meetingKey)
        try saveStoreFile(store)
    }

    public func deleteAll() throws {
        let store = StoreFile(schemaVersion: config.schemaVersion, meetings: [:])
        try saveStoreFile(store)
    }

    // MARK: - Pruning

    private func prune(_ store: StoreFile) -> StoreFile {
        let cutoff = now().addingTimeInterval(-config.maxAge)

        var retained: [(key: String, entry: MeetingEntry)] = []
        retained.reserveCapacity(store.meetings.count)

        for (key, entry) in store.meetings {
            if entry.updatedAt >= cutoff {
                retained.append((key: key, entry: entry))
            }
        }

        retained.sort { a, b in
            if a.entry.updatedAt != b.entry.updatedAt { return a.entry.updatedAt > b.entry.updatedAt }
            return a.key < b.key
        }

        if retained.count > config.maxMeetings {
            retained = Array(retained.prefix(config.maxMeetings))
        }

        return StoreFile(schemaVersion: store.schemaVersion, meetings: Dictionary(uniqueKeysWithValues: retained.map { ($0.key, $0.entry) }))
    }

    // MARK: - Persistence

    private func loadStoreFile() throws -> StoreFile {
        if !FileManager.default.fileExists(atPath: config.storeURL.path) {
            return StoreFile(schemaVersion: config.schemaVersion, meetings: [:])
        }

        do {
            let data = try Data(contentsOf: config.storeURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(StoreFile.self, from: data)

            guard decoded.schemaVersion == config.schemaVersion else {
                throw MeetingSpeakerEmbeddingCacheError.invalidStoreSchemaVersion
            }
            return decoded
        } catch let error as MeetingSpeakerEmbeddingCacheError {
            throw error
        } catch {
            throw MeetingSpeakerEmbeddingCacheError.decodingFailed
        }
    }

    private func saveStoreFile(_ store: StoreFile) throws {
        try FileManager.default.createDirectory(
            at: config.storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(store)
        try data.write(to: config.storeURL, options: [.atomic])
    }
}
