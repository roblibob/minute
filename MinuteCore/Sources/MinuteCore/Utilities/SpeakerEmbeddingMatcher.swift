import Foundation

public enum SpeakerEmbeddingMatcherError: Error, LocalizedError, Sendable, Equatable {
    case dimensionMismatch(expected: Int, actual: Int)

    public var errorDescription: String? {
        switch self {
        case .dimensionMismatch(let expected, let actual):
            return "Embedding must have dimension \(expected) (got \(actual))."
        }
    }
}

public struct SpeakerEmbeddingMatcher: Sendable {
    public struct Match: Sendable, Equatable {
        public var profile: SpeakerProfile
        public var similarity: Double
    }

    public struct Thresholds: Sendable, Equatable {
        /// Minimum cosine similarity required to consider a profile a match.
        ///
        /// Note: this is intentionally conservative; profile enrollment/matching should err on the side of no suggestion.
        public var minCosineSimilarity: Double

        public init(minCosineSimilarity: Double) {
            self.minCosineSimilarity = minCosineSimilarity
        }

        public static let `default` = Thresholds(minCosineSimilarity: 0.7)
    }

    public init() {}

    public func bestMatch(
        embedding: [Float],
        candidates: [SpeakerProfile],
        embeddingModelVersion: String,
        thresholds: Thresholds = .default
    ) throws -> Match? {
        guard embedding.count == SpeakerProfile.embeddingDimension else {
            throw SpeakerEmbeddingMatcherError.dimensionMismatch(
                expected: SpeakerProfile.embeddingDimension,
                actual: embedding.count
            )
        }

        var best: Match?
        for profile in candidates where profile.embeddingModelVersion == embeddingModelVersion {
            var bestSimForProfile: Double?
            for stored in profile.embeddings {
                let sim = try cosineSimilarity(a: embedding, b: stored)
                if let current = bestSimForProfile {
                    if sim > current { bestSimForProfile = sim }
                } else {
                    bestSimForProfile = sim
                }
            }
            guard let sim = bestSimForProfile else { continue }
            if sim < thresholds.minCosineSimilarity { continue }

            let candidate = Match(profile: profile, similarity: sim)
            if let current = best {
                if sim > current.similarity {
                    best = candidate
                } else if sim == current.similarity {
                    // Deterministic tie-break.
                    if profile.id < current.profile.id {
                        best = candidate
                    }
                }
            } else {
                best = candidate
            }
        }
        return best
    }

    public func cosineSimilarity(a: [Float], b: [Float]) throws -> Double {
        guard a.count == SpeakerProfile.embeddingDimension else {
            throw SpeakerEmbeddingMatcherError.dimensionMismatch(
                expected: SpeakerProfile.embeddingDimension,
                actual: a.count
            )
        }
        guard b.count == SpeakerProfile.embeddingDimension else {
            throw SpeakerEmbeddingMatcherError.dimensionMismatch(
                expected: SpeakerProfile.embeddingDimension,
                actual: b.count
            )
        }

        var dot: Double = 0
        var aNorm: Double = 0
        var bNorm: Double = 0

        for i in 0..<SpeakerProfile.embeddingDimension {
            let av = Double(a[i])
            let bv = Double(b[i])
            dot += av * bv
            aNorm += av * av
            bNorm += bv * bv
        }

        let denom = (aNorm.squareRoot() * bNorm.squareRoot())
        if denom == 0 { return 0 }
        return dot / denom
    }
}
