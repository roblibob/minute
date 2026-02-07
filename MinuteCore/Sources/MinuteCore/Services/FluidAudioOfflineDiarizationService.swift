@preconcurrency import FluidAudio
import Foundation
import os

public struct FluidAudioOfflineDiarizationConfiguration: Sendable, Equatable {
    public var embeddingExportPath: URL?

    public init(embeddingExportPath: URL? = nil) {
        self.embeddingExportPath = embeddingExportPath
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
        FluidAudioOfflineDiarizationService(
            configuration: FluidAudioOfflineDiarizationConfiguration(),
            offlineManager: FluidAudioOfflineDiarizerManagerAdapter(configuration: FluidAudioOfflineDiarizationConfiguration())
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

            let config = makeConfig(configuration, embeddingExportURL: embeddingExportURL)

            Logger(subsystem: "roblibob.Minute", category: "diarization").info("Running offline diarization")

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

        private func makeConfig(
            _ configuration: FluidAudioOfflineDiarizationConfiguration,
            embeddingExportURL: URL?
        ) -> OfflineDiarizerConfig {
            var config = OfflineDiarizerConfig()
            let exportPath = embeddingExportURL ?? configuration.embeddingExportPath
            if let exportPath {
                config.embeddingExportPath = exportPath.path
            }
            return config
        }
    }
}

private actor FluidAudioOfflineModelPreparer {
    static let shared = FluidAudioOfflineModelPreparer()

    private var didPrepare = false

    func ensurePrepared(configuration: FluidAudioOfflineDiarizationConfiguration) async throws {
        if didPrepare { return }

        let config = OfflineDiarizerConfig()

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
