import Foundation

public enum SpeakerProfileValidationError: Error, LocalizedError, Sendable, Equatable {
    case emptyName
    case emptyID
    case emptyEmbeddings
    case invalidEmbeddingLength(expected: Int, actual: Int)
    case emptyEmbeddingModelVersion

    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Speaker profile name must not be empty."
        case .emptyID:
            return "Speaker profile id must not be empty."
        case .emptyEmbeddings:
            return "Speaker profile must contain at least one embedding."
        case .invalidEmbeddingLength(let expected, let actual):
            return "Speaker profile embedding must have length \(expected) (got \(actual))."
        case .emptyEmbeddingModelVersion:
            return "Speaker profile embeddingModelVersion must not be empty."
        }
    }
}

public struct SpeakerProfile: Sendable, Equatable, Codable, Identifiable {
    public static let embeddingDimension = 256

    public var id: String
    public var name: String
    public var embeddings: [[Float]]
    public var embeddingModelVersion: String
    public var createdAt: Date
    public var updatedAt: Date
    public var isPermanent: Bool

    public init(
        id: String,
        name: String,
        embeddings: [[Float]],
        embeddingModelVersion: String,
        createdAt: Date,
        updatedAt: Date,
        isPermanent: Bool
    ) throws {
        self.id = id
        self.name = name
        self.embeddings = embeddings
        self.embeddingModelVersion = embeddingModelVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPermanent = isPermanent

        try validate()
    }

    public func validated() throws -> SpeakerProfile {
        let copy = self
        try copy.validate()
        return copy
    }

    private func validate() throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw SpeakerProfileValidationError.emptyName
        }
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SpeakerProfileValidationError.emptyID
        }
        guard !embeddings.isEmpty else {
            throw SpeakerProfileValidationError.emptyEmbeddings
        }
        for embedding in embeddings {
            guard embedding.count == Self.embeddingDimension else {
                throw SpeakerProfileValidationError.invalidEmbeddingLength(
                    expected: Self.embeddingDimension,
                    actual: embedding.count
                )
            }
        }
        guard !embeddingModelVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SpeakerProfileValidationError.emptyEmbeddingModelVersion
        }
    }
}
