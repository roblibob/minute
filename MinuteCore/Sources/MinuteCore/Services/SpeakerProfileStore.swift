import Foundation

public enum SpeakerProfileStoreError: Error, LocalizedError, Sendable, Equatable {
    case profileNotFound
    case invalidStoreSchemaVersion
    case decodingFailed

    public var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return "Speaker profile not found."
        case .invalidStoreSchemaVersion:
            return "Speaker profile store format is not supported."
        case .decodingFailed:
            return "Failed to read speaker profile store."
        }
    }
}

public actor SpeakerProfileStore {
    public struct Configuration: Sendable {
        public var storeURL: URL
        public var schemaVersion: Int

        public init(storeURL: URL, schemaVersion: Int = 1) {
            self.storeURL = storeURL
            self.schemaVersion = schemaVersion
        }

        public static func `default`() -> Configuration {
            let applicationSupportRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")

            let storeURL = applicationSupportRoot
                .appendingPathComponent("Minute", isDirectory: true)
                .appendingPathComponent("speaker_profiles.json")

            return Configuration(storeURL: storeURL, schemaVersion: 1)
        }
    }

    private struct StoreFile: Codable, Sendable, Equatable {
        var schemaVersion: Int
        var profiles: [SpeakerProfile]
    }

    private let config: Configuration
    private let now: @Sendable () -> Date
    private let idGenerator: @Sendable () -> String

    public init(
        config: Configuration = .default(),
        now: @escaping @Sendable () -> Date = { Date() },
        idGenerator: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.config = config
        self.now = now
        self.idGenerator = idGenerator
    }

    public func listProfiles() throws -> [SpeakerProfile] {
        let store = try loadStoreFile()
        return store.profiles.sorted {
            let a = $0.name.localizedCaseInsensitiveCompare($1.name)
            if a == .orderedSame {
                return $0.id < $1.id
            }
            return a == .orderedAscending
        }
    }

    public func createProfile(name: String, embedding: [Float], embeddingModelVersion: String, isPermanent: Bool = false) throws -> SpeakerProfile {
        var store = try loadStoreFile()
        let timestamp = now()
        let profile = try SpeakerProfile(
            id: idGenerator(),
            name: name,
            embedding: embedding,
            embeddingModelVersion: embeddingModelVersion,
            createdAt: timestamp,
            updatedAt: timestamp,
            isPermanent: isPermanent
        )

        store.profiles.append(profile)
        try saveStoreFile(store)
        return profile
    }

    public func updateProfile(profileID: String, name: String? = nil, isPermanent: Bool? = nil) throws -> SpeakerProfile {
        var store = try loadStoreFile()
        guard let index = store.profiles.firstIndex(where: { $0.id == profileID }) else {
            throw SpeakerProfileStoreError.profileNotFound
        }

        var updated = store.profiles[index]
        if let name {
            updated.name = name
        }
        if let isPermanent {
            updated.isPermanent = isPermanent
        }
        updated.updatedAt = now()
        updated = try updated.validated()

        store.profiles[index] = updated
        try saveStoreFile(store)
        return updated
    }

    public func updateProfileEmbedding(profileID: String, embedding: [Float], embeddingModelVersion: String) throws -> SpeakerProfile {
        var store = try loadStoreFile()
        guard let index = store.profiles.firstIndex(where: { $0.id == profileID }) else {
            throw SpeakerProfileStoreError.profileNotFound
        }

        var updated = store.profiles[index]
        updated.embedding = embedding
        updated.embeddingModelVersion = embeddingModelVersion
        updated.updatedAt = now()
        updated = try updated.validated()

        store.profiles[index] = updated
        try saveStoreFile(store)
        return updated
    }

    public func deleteProfile(profileID: String) throws {
        var store = try loadStoreFile()
        let beforeCount = store.profiles.count
        store.profiles.removeAll { $0.id == profileID }
        guard store.profiles.count != beforeCount else {
            throw SpeakerProfileStoreError.profileNotFound
        }
        try saveStoreFile(store)
    }

    // MARK: - Persistence

    private func loadStoreFile() throws -> StoreFile {
        if !FileManager.default.fileExists(atPath: config.storeURL.path) {
            return StoreFile(schemaVersion: config.schemaVersion, profiles: [])
        }

        do {
            let data = try Data(contentsOf: config.storeURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(StoreFile.self, from: data)

            guard decoded.schemaVersion == config.schemaVersion else {
                throw SpeakerProfileStoreError.invalidStoreSchemaVersion
            }
            return decoded
        } catch let error as SpeakerProfileStoreError {
            throw error
        } catch {
            throw SpeakerProfileStoreError.decodingFailed
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
