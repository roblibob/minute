import Foundation
import Testing
@testable import MinuteCore

struct OfflineDiarizerEmbeddingExportTests {
    @Test
    func aggregateByCluster_isDeterministicAndNormalized() throws {
        let e0 = OfflineDiarizerEmbeddingExport.Entry(
            chunkIndex: 2,
            speakerIndex: 0,
            startFrame: 10,
            endFrame: 20,
            startTime: 2.0,
            endTime: 3.0,
            embedding256: unitVector(index: 0),
            cluster: 0
        )

        let e1 = OfflineDiarizerEmbeddingExport.Entry(
            chunkIndex: 1,
            speakerIndex: 0,
            startFrame: 5,
            endFrame: 9,
            startTime: 1.0,
            endTime: 1.5,
            embedding256: unitVector(index: 0),
            cluster: 0
        )

        // Deliberately out-of-order input.
        let aggregated = try OfflineDiarizerEmbeddingExport.aggregateByCluster(entries: [e0, e1])
        #expect(aggregated.count == 1)

        let embedding = aggregated[0].embedding
        #expect(embedding.count == OfflineDiarizerEmbeddingExport.embeddingDimension)

        // Should remain a unit vector on index 0.
        #expect(abs(Double(embedding[0]) - 1.0) < 1e-6)
        #expect(embedding[1...].allSatisfy { abs(Double($0)) < 1e-6 })
    }
}

private func unitVector(index: Int) -> [Float] {
    var v = [Float](repeating: 0, count: OfflineDiarizerEmbeddingExport.embeddingDimension)
    v[index] = 1
    return v
}
