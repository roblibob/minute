@preconcurrency import FluidAudio
import Foundation
import os

public struct FluidAudioLiveTranscriptionConfiguration: Sendable, Equatable {
    public var modelVersionKey: String
    public var audioSource: AudioSource

    public init(modelVersionKey: String, audioSource: AudioSource = .microphone) {
        self.modelVersionKey = modelVersionKey
        self.audioSource = audioSource
    }
}

public actor FluidAudioLiveTranscriptionService: LiveTranscriptionServicing {
    private let configuration: FluidAudioLiveTranscriptionConfiguration
    private let logger = Logger(subsystem: "roblibob.Minute", category: "fluidaudio.asr.live")
    private var asrManager: AsrManager?
    private var loadedVersion: AsrModelVersion?

    public init(configuration: FluidAudioLiveTranscriptionConfiguration) {
        self.configuration = configuration
    }

    public static func liveDefault(
        selectionStore: FluidAudioASRModelSelectionStore = FluidAudioASRModelSelectionStore()
    ) -> FluidAudioLiveTranscriptionService {
        let selected = selectionStore.selectedModel()
        return FluidAudioLiveTranscriptionService(
            configuration: FluidAudioLiveTranscriptionConfiguration(
                modelVersionKey: selected.versionKey,
                audioSource: .microphone
            )
        )
    }

    public func transcribe(samples: [Float]) async throws -> String {
        try Task.checkCancellation()
        guard !samples.isEmpty else { return "" }

        let minSamples = ASRConfig.default.sampleRate
        if samples.count < minSamples {
            logger.debug("Skipping live ASR; need >= \(minSamples) samples, got \(samples.count)")
            return ""
        }

        let version = FluidAudioASRVersionResolver.version(for: configuration.modelVersionKey)
        let models = try await FluidAudioASRLiveModelCache.shared.models(version: version)
        let manager = try await ensureManager(models: models, version: version)

        let start = Date()
        do {
            let result = try await manager.transcribe(samples, source: configuration.audioSource)
            let elapsed = Date().timeIntervalSince(start)
            let seconds = String(format: "%.2f", Double(samples.count) / 16000.0)
            let elapsedString = String(format: "%.2f", elapsed)
            logger.debug("Live ASR ok: samples=\(samples.count) secs=\(seconds) elapsed=\(elapsedString) textLength=\(result.text.count)")
            return result.text
        } catch {
            logger.error("FluidAudio live ASR failed: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
            throw MinuteError.transcriptionFailed(underlyingDescription: ErrorHandler.debugMessage(for: error))
        }
    }

    private func ensureManager(models: AsrModels, version: AsrModelVersion) async throws -> AsrManager {
        if let asrManager, loadedVersion == version {
            return asrManager
        }

        logger.info("Initializing FluidAudio live ASR for version: \(String(describing: version), privacy: .public)")
        let manager = AsrManager(config: .default)
        try await manager.initialize(models: models)
        asrManager = manager
        loadedVersion = version
        return manager
    }
}

private actor FluidAudioASRLiveModelCache {
    static let shared = FluidAudioASRLiveModelCache()
    private var cached: [String: AsrModels] = [:]

    func models(version: AsrModelVersion) async throws -> AsrModels {
        let key = version.cacheKey
        if let cached = cached[key] {
            return cached
        }

        let models = try await AsrModels.downloadAndLoad(version: version)
        cached[key] = models
        return models
    }
}

private extension AsrModelVersion {
    var cacheKey: String {
        switch self {
        case .v2:
            return "v2"
        case .v3:
            return "v3"
        }
    }
}
