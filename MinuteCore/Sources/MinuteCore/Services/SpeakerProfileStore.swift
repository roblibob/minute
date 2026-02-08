import Foundation

public enum SpeakerProfileStoreError: Error, LocalizedError, Sendable, Equatable {
    case profileNotFound
    case invalidStoreSchemaVersion
    case decodingFailed
    case embeddingModelVersionMismatch

    public var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return "Speaker profile not found."
        case .invalidStoreSchemaVersion:
            return "Speaker profile store format is not supported."
        case .decodingFailed:
            return "Failed to read speaker profile store."
        case .embeddingModelVersionMismatch:
            return "Speaker profile embedding model version does not match."
        }
    }
}

public actor SpeakerProfileStore {
    public struct Configuration: Sendable {
        public var storeURL: URL
        public var schemaVersion: Int

        public init(storeURL: URL, schemaVersion: Int = 2) {
            self.storeURL = storeURL
            self.schemaVersion = schemaVersion
        }

        public static func `default`() -> Configuration {
            let applicationSupportRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")

            let storeURL = applicationSupportRoot
                .appendingPathComponent("Minute", isDirectory: true)
                .appendingPathComponent("speaker_profiles.json")

            return Configuration(storeURL: storeURL, schemaVersion: 2)
        }
    }

    private struct StoreFileV2: Codable, Sendable, Equatable {
        var schemaVersion: Int
        var profiles: [SpeakerProfile]
    }

    private struct StoreFileV1: Codable, Sendable, Equatable {
        var schemaVersion: Int
        var profiles: [SpeakerProfileV1]
    }

    private struct SpeakerProfileV1: Codable, Sendable, Equatable {
        var id: String
        var name: String
        var embedding: [Float]
        var embeddingModelVersion: String
        var createdAt: Date
        var updatedAt: Date
        var isPermanent: Bool
    }

    private let config: Configuration
    private let now: @Sendable () -> Date
    private let idGenerator: @Sendable () -> String

    private static let currentSchemaVersion: Int = 2
    private static let maxEmbeddingsPerProfile: Int = 20

    public init(
        config: Configuration = .default(),
        now: @escaping @Sendable () -> Date = { Date() },
        idGenerator: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        var effectiveConfig = config
        if effectiveConfig.schemaVersion < Self.currentSchemaVersion {
            effectiveConfig.schemaVersion = Self.currentSchemaVersion
        }
        self.config = effectiveConfig
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

    public func createOrAppendProfile(
        name: String,
        embedding: [Float],
        embeddingModelVersion: String,
        isPermanent: Bool = false
    ) throws -> SpeakerProfile {
        var store = try loadStoreFile()
        let timestamp = now()
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let compareLocale = Locale(identifier: "en_US_POSIX")
        let normalized = trimmedName
            .folding(options: [.diacriticInsensitive], locale: compareLocale)
            .lowercased()

        if let index = store.profiles.firstIndex(where: {
            $0.embeddingModelVersion == embeddingModelVersion &&
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.diacriticInsensitive], locale: compareLocale)
                .lowercased() == normalized
        }) {
            var updated = store.profiles[index]
            updated.name = trimmedName.isEmpty ? updated.name : trimmedName
            updated.isPermanent = updated.isPermanent || isPermanent
            updated.updatedAt = timestamp

            updated.embeddings.append(embedding)
            if updated.embeddings.count > Self.maxEmbeddingsPerProfile {
                updated.embeddings.removeFirst(updated.embeddings.count - Self.maxEmbeddingsPerProfile)
            }

            updated = try updated.validated()
            store.profiles[index] = updated
            try saveStoreFile(store)
            return updated
        }

        let profile = try SpeakerProfile(
            id: idGenerator(),
            name: trimmedName,
            embeddings: [embedding],
            embeddingModelVersion: embeddingModelVersion,
            createdAt: timestamp,
            updatedAt: timestamp,
            isPermanent: isPermanent
        )

        store.profiles.append(profile)
        try saveStoreFile(store)
        return profile
    }

    public func createProfile(name: String, embedding: [Float], embeddingModelVersion: String, isPermanent: Bool = false) throws -> SpeakerProfile {
        // Keep a dedicated creator for callers that explicitly want a new profile.
        var store = try loadStoreFile()
        let timestamp = now()
        let profile = try SpeakerProfile(
            id: idGenerator(),
            name: name,
            embeddings: [embedding],
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
        guard updated.embeddingModelVersion == embeddingModelVersion else {
            throw SpeakerProfileStoreError.embeddingModelVersionMismatch
        }
        updated.embeddings.append(embedding)
        if updated.embeddings.count > Self.maxEmbeddingsPerProfile {
            updated.embeddings.removeFirst(updated.embeddings.count - Self.maxEmbeddingsPerProfile)
        }
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

    private func loadStoreFile() throws -> StoreFileV2 {
        if !FileManager.default.fileExists(atPath: config.storeURL.path) {
            return StoreFileV2(schemaVersion: config.schemaVersion, profiles: [])
        }

        do {
            let data = try Data(contentsOf: config.storeURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            if var decodedV2 = try? decoder.decode(StoreFileV2.self, from: data) {
                if decodedV2.schemaVersion == config.schemaVersion {
                    return decodedV2
                }
                if decodedV2.schemaVersion == 1, config.schemaVersion == 2 {
                    // If a v2-shaped file exists but reports schemaVersion=1, normalize it to v2.
                    decodedV2.schemaVersion = 2
                    try saveStoreFile(decodedV2)
                    return decodedV2
                }

                throw SpeakerProfileStoreError.invalidStoreSchemaVersion
            }

            if let decodedV1 = try? decoder.decode(StoreFileV1.self, from: data) {
                guard decodedV1.schemaVersion == 1, config.schemaVersion == 2 else {
                    throw SpeakerProfileStoreError.invalidStoreSchemaVersion
                }

                let migratedProfiles: [SpeakerProfile] = try decodedV1.profiles.map { v1 in
                    try SpeakerProfile(
                        id: v1.id,
                        name: v1.name,
                        embeddings: [v1.embedding],
                        embeddingModelVersion: v1.embeddingModelVersion,
                        createdAt: v1.createdAt,
                        updatedAt: v1.updatedAt,
                        isPermanent: v1.isPermanent
                    )
                }
                let migrated = StoreFileV2(schemaVersion: 2, profiles: migratedProfiles)
                try saveStoreFile(migrated)
                return migrated
            }

            throw SpeakerProfileStoreError.decodingFailed
        } catch let error as SpeakerProfileStoreError {
            throw error
        } catch {
            throw SpeakerProfileStoreError.decodingFailed
        }
    }

    private func saveStoreFile(_ store: StoreFileV2) throws {
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
