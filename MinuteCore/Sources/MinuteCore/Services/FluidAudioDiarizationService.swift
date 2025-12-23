@preconcurrency private import FluidAudio
import Foundation
import os

public struct FluidAudioDiarizationConfiguration: Sendable, Equatable {
    public var clusteringThreshold: Double?
    public var minSpeechDuration: Double?
    public var minEmbeddingUpdateDuration: Double?
    public var minSilenceGap: Double?
    public var numClusters: Int?
    public var chunkOverlap: Double?
    public var minActiveFramesCount: Double?

    public init(
        clusteringThreshold: Double? = nil,
        minSpeechDuration: Double? = nil,
        minEmbeddingUpdateDuration: Double? = nil,
        minSilenceGap: Double? = nil,
        numClusters: Int? = nil,
        chunkOverlap: Double? = nil,
        minActiveFramesCount: Double? = nil
    ) {
        self.clusteringThreshold = clusteringThreshold
        self.minSpeechDuration = minSpeechDuration
        self.minEmbeddingUpdateDuration = minEmbeddingUpdateDuration
        self.minSilenceGap = minSilenceGap
        self.numClusters = numClusters
        self.chunkOverlap = chunkOverlap
        self.minActiveFramesCount = minActiveFramesCount
    }
}

public struct FluidAudioDiarizationService: DiarizationServicing {
    private let configuration: FluidAudioDiarizationConfiguration

    public init(configuration: FluidAudioDiarizationConfiguration) {
        self.configuration = configuration
    }

    public static func liveDefault() -> FluidAudioDiarizationService {
        FluidAudioDiarizationService(configuration: FluidAudioDiarizationConfiguration())
    }

    public static func meetingDefault() -> FluidAudioDiarizationService {
        FluidAudioDiarizationService(
            configuration: FluidAudioDiarizationConfiguration(
                clusteringThreshold: 0.55,
                minSpeechDuration: 0.4,
                minEmbeddingUpdateDuration: 1.0,
                minSilenceGap: 0.25,
                chunkOverlap: 1.0,
                minActiveFramesCount: 6.0
            )
        )
    }

    public func diarize(wavURL: URL) async throws -> [SpeakerSegment] {
        try Task.checkCancellation()

        let models = try await FluidAudioModelCache.shared.models()
        let config = makeConfig()

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    Logger(subsystem: "roblibob.Minute", category: "diarization").info("Running diarization")
                    let diarizer = DiarizerManager(config: config)
                    diarizer.initialize(models: models)

                    let samples = try AudioConverter().resampleAudioFile(wavURL)
                    let result: DiarizationResult = try diarizer.performCompleteDiarization(samples)

                    var speakerIdMap: [String: Int] = [:]
                    var nextSpeakerId = 1

                    let segments = result.segments.map { segment in
                        let id = mapSpeakerId(segment.speakerId, map: &speakerIdMap, nextId: &nextSpeakerId)
                        return SpeakerSegment(
                            startSeconds: Double(segment.startTimeSeconds),
                            endSeconds: Double(segment.endTimeSeconds),
                            speakerId: id
                        )
                    }

                    continuation.resume(returning: segments)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func makeConfig() -> DiarizerConfig {
        var config = DiarizerConfig()

        if let clusteringThreshold = configuration.clusteringThreshold {
            config.clusteringThreshold = Float(clusteringThreshold)
        }

        if let minSpeechDuration = configuration.minSpeechDuration {
            config.minSpeechDuration = Float(minSpeechDuration)
        }

        if let minEmbeddingUpdateDuration = configuration.minEmbeddingUpdateDuration {
            config.minEmbeddingUpdateDuration = Float(minEmbeddingUpdateDuration)
        }

        if let minSilenceGap = configuration.minSilenceGap {
            config.minSilenceGap = Float(minSilenceGap)
        }

        if let numClusters = configuration.numClusters {
            config.numClusters = numClusters
        }

        if let chunkOverlap = configuration.chunkOverlap {
            config.chunkOverlap = Float(chunkOverlap)
        }

        if let minActiveFramesCount = configuration.minActiveFramesCount {
            config.minActiveFramesCount = Float(minActiveFramesCount)
        }

        return config
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

private actor FluidAudioModelCache {
    static let shared = FluidAudioModelCache()
    private var cached: DiarizerModels?

    func models() async throws -> DiarizerModels {
        if let cached {
            return cached
        }

        let models = try await DiarizerModels.downloadIfNeeded()
        cached = models
        return models
    }
}
