import Foundation

public enum OfflineDiarizerEmbeddingExport {
    public struct Entry: Sendable, Equatable, Codable {
        public var chunkIndex: Int
        public var speakerIndex: Int
        public var startFrame: Int
        public var endFrame: Int
        public var startTime: Double
        public var endTime: Double
        public var embedding256: [Float]
        public var cluster: Int

        public init(
            chunkIndex: Int,
            speakerIndex: Int,
            startFrame: Int,
            endFrame: Int,
            startTime: Double,
            endTime: Double,
            embedding256: [Float],
            cluster: Int
        ) {
            self.chunkIndex = chunkIndex
            self.speakerIndex = speakerIndex
            self.startFrame = startFrame
            self.endFrame = endFrame
            self.startTime = startTime
            self.endTime = endTime
            self.embedding256 = embedding256
            self.cluster = cluster
        }
    }

    public struct AggregatedSpeakerEmbedding: Sendable, Equatable {
        public var speakerCluster: Int
        public var embedding: [Float]

        public init(speakerCluster: Int, embedding: [Float]) {
            self.speakerCluster = speakerCluster
            self.embedding = embedding
        }
    }

    public enum ExportError: Error, Sendable, Equatable {
        case invalidEmbeddingLength(expected: Int, actual: Int)
        case emptyExport
        case zeroVector
    }

    public static let embeddingDimension = 256

    public static func load(from url: URL) throws -> [Entry] {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode([Entry].self, from: data)
    }

    /// Deterministically aggregates embeddings into one L2-normalized vector per `cluster`.
    ///
    /// Important: sorting before summation ensures stable floating-point accumulation order.
    public static func aggregateByCluster(entries: [Entry]) throws -> [AggregatedSpeakerEmbedding] {
        guard !entries.isEmpty else { throw ExportError.emptyExport }

        let sorted = entries.sorted { a, b in
            if a.cluster != b.cluster { return a.cluster < b.cluster }
            if a.chunkIndex != b.chunkIndex { return a.chunkIndex < b.chunkIndex }
            if a.startFrame != b.startFrame { return a.startFrame < b.startFrame }
            if a.endFrame != b.endFrame { return a.endFrame < b.endFrame }
            if a.startTime != b.startTime { return a.startTime < b.startTime }
            return a.endTime < b.endTime
        }

        var sumsByCluster: [Int: [Double]] = [:]
        var countsByCluster: [Int: Int] = [:]

        for entry in sorted {
            if entry.embedding256.count != embeddingDimension {
                throw ExportError.invalidEmbeddingLength(expected: embeddingDimension, actual: entry.embedding256.count)
            }

            if sumsByCluster[entry.cluster] == nil {
                sumsByCluster[entry.cluster] = Array(repeating: 0, count: embeddingDimension)
                countsByCluster[entry.cluster] = 0
            }

            countsByCluster[entry.cluster, default: 0] += 1
            for i in 0..<embeddingDimension {
                sumsByCluster[entry.cluster]![i] += Double(entry.embedding256[i])
            }
        }

        let clusters = sumsByCluster.keys.sorted()
        var results: [AggregatedSpeakerEmbedding] = []
        results.reserveCapacity(clusters.count)

        for cluster in clusters {
            guard let sum = sumsByCluster[cluster], let count = countsByCluster[cluster], count > 0 else {
                continue
            }
            let inv = 1.0 / Double(count)
            var mean = [Float](repeating: 0, count: embeddingDimension)
            for i in 0..<embeddingDimension {
                mean[i] = Float(sum[i] * inv)
            }

            let normalized = try l2Normalize(mean)
            results.append(AggregatedSpeakerEmbedding(speakerCluster: cluster, embedding: normalized))
        }

        return results
    }

    private static func l2Normalize(_ vector: [Float]) throws -> [Float] {
        var sumSquares: Double = 0
        for value in vector {
            let v = Double(value)
            sumSquares += v * v
        }

        guard sumSquares.isFinite, sumSquares > 0 else {
            throw ExportError.zeroVector
        }

        let invNorm = 1.0 / sqrt(sumSquares)
        return vector.map { Float(Double($0) * invNorm) }
    }
}

public enum SpeakerEmbeddingModelVersions {
    /// Embeddings exported by FluidAudio offline diarization (VBx) using the 256-d embedding model.
    public static let fluidAudioOfflineVbx256 = "fluidAudio.offline.vbx.embedding256.v1"
}
