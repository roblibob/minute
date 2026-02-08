@preconcurrency import FluidAudio
import Foundation
import os

public struct FluidAudioOfflineDiarizationConfiguration: Sendable, Equatable {
    public var embeddingExportPath: URL?
    public var clusteringThreshold: Double?

    public init(
        embeddingExportPath: URL? = nil,
        clusteringThreshold: Double? = nil
    ) {
        self.embeddingExportPath = embeddingExportPath
        self.clusteringThreshold = clusteringThreshold
    }
}

/// Offline (VBx) diarization for post-meeting processing.
public struct FluidAudioOfflineDiarizationService: DiarizationServicing {
    private let configuration: FluidAudioOfflineDiarizationConfiguration
    private let offlineManager: any OfflineDiarizerManaging

    public init(
        configuration: FluidAudioOfflineDiarizationConfiguration,
        offlineManager: some OfflineDiarizerManaging
    ) {
        self.configuration = configuration
        self.offlineManager = offlineManager
    }

    public static func meetingDefault() -> FluidAudioOfflineDiarizationService {
        let configuration = FluidAudioOfflineDiarizationConfiguration(
            clusteringThreshold: 0.8
        )
        return FluidAudioOfflineDiarizationService(
            configuration: configuration,
            offlineManager: FluidAudioOfflineDiarizerManagerAdapter(configuration: configuration)
        )
    }

    public func diarize(wavURL: URL, embeddingExportURL: URL?) async throws -> [SpeakerSegment] {
        try Task.checkCancellation()
        try await offlineManager.prepareModels()
        try Task.checkCancellation()
        return try await offlineManager.diarize(wavURL: wavURL, embeddingExportURL: embeddingExportURL)
    }

    private struct FluidAudioOfflineDiarizerManagerAdapter: OfflineDiarizerManaging {
        let configuration: FluidAudioOfflineDiarizationConfiguration

        func prepareModels() async throws {
            try await FluidAudioOfflineModelPreparer.shared.ensurePrepared(configuration: configuration)
        }

        func diarize(wavURL: URL, embeddingExportURL: URL?) async throws -> [SpeakerSegment] {
            try Task.checkCancellation()

            let config = makeOfflineDiarizerConfig(configuration, embeddingExportURL: embeddingExportURL)

            // Fail fast if misconfigured (also confirms the threshold is set on the config).
            try config.validate()

            Logger(subsystem: "roblibob.Minute", category: "diarization")
                .info("Running offline diarization (clusteringThreshold=\(config.clustering.threshold, privacy: .public))")

            let manager = OfflineDiarizerManager(config: config)
            let result: DiarizationResult = try await manager.process(wavURL)

            var speakerIdMap: [String: Int] = [:]
            var nextSpeakerId = 1

            return result.segments.map { segment in
                let raw = String(describing: segment.speakerId)
                let id = mapSpeakerId(raw, map: &speakerIdMap, nextId: &nextSpeakerId)
                return SpeakerSegment(
                    startSeconds: Double(segment.startTimeSeconds),
                    endSeconds: Double(segment.endTimeSeconds),
                    speakerId: id
                )
            }
        }
    }
}

func makeOfflineDiarizerConfig(
    _ configuration: FluidAudioOfflineDiarizationConfiguration,
    embeddingExportURL: URL?
) -> OfflineDiarizerConfig {
    var config = OfflineDiarizerConfig()

    if let clusteringThreshold = configuration.clusteringThreshold {
        config.clustering.threshold = clusteringThreshold
    }

    let exportPath = embeddingExportURL ?? configuration.embeddingExportPath
    if let exportPath {
        config.embeddingExportPath = exportPath.path
    }

    return config
}

private actor FluidAudioOfflineModelPreparer {
    static let shared = FluidAudioOfflineModelPreparer()

    private var didPrepare = false

    func ensurePrepared(configuration: FluidAudioOfflineDiarizationConfiguration) async throws {
        if didPrepare { return }

        let config = makeOfflineDiarizerConfig(configuration, embeddingExportURL: nil)

        let manager = OfflineDiarizerManager(config: config)
        try await manager.prepareModels()

        didPrepare = true
    }
}

private func mapSpeakerId(_ raw: String, map: inout [String: Int], nextId: inout Int) -> Int {
    if let existing = map[raw] {
        return existing
    }

    let parsed = raw.split(whereSeparator: { !$0.isNumber }).last.flatMap { Int($0) }
    let assigned = parsed ?? nextId
    if parsed == nil {
        nextId += 1
    }
    map[raw] = assigned
    return assigned
}
