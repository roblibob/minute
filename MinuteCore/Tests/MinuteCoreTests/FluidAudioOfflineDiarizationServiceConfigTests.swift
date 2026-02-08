import Foundation
import FluidAudio
import Testing
@testable import MinuteCore

struct FluidAudioOfflineDiarizationServiceConfigTests {
    @Test
    func makeOfflineDiarizerConfig_appliesClusteringThreshold() throws {
        let config = makeOfflineDiarizerConfig(
            .init(clusteringThreshold: 0.7),
            embeddingExportURL: nil
        )

        #expect(config.clustering.threshold == 0.7)
    }
}
