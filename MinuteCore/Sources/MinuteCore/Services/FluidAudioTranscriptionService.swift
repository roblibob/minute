@preconcurrency import FluidAudio
import Foundation
import os

public struct FluidAudioTranscriptionConfiguration: Sendable, Equatable {
    public var modelVersionKey: String
    public var audioSource: AudioSource

    public init(modelVersionKey: String, audioSource: AudioSource = .system) {
        self.modelVersionKey = modelVersionKey
        self.audioSource = audioSource
    }
}

public struct FluidAudioTranscriptionService: TranscriptionServicing {
    private let configuration: FluidAudioTranscriptionConfiguration
    private let logger = Logger(subsystem: "roblibob.Minute", category: "fluidaudio.asr")

    public init(configuration: FluidAudioTranscriptionConfiguration) {
        self.configuration = configuration
    }

    public static func liveDefault(
        selectionStore: FluidAudioASRModelSelectionStore = FluidAudioASRModelSelectionStore()
    ) -> FluidAudioTranscriptionService {
        let selected = selectionStore.selectedModel()
        return FluidAudioTranscriptionService(
            configuration: FluidAudioTranscriptionConfiguration(
                modelVersionKey: selected.versionKey
            )
        )
    }

    public func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        try Task.checkCancellation()

        let version = FluidAudioASRVersionResolver.version(for: configuration.modelVersionKey)
        let models = try await FluidAudioASRModelCache.shared.models(version: version)
        let duration = (try? ContractWavVerifier.durationSeconds(ofContractWavAt: wavURL)) ?? 0
        logger.debug("FluidAudio ASR starting: version=\(configuration.modelVersionKey, privacy: .public) duration=\(String(format: "%.2f", duration), privacy: .public)s")

        let manager = AsrManager(config: .default)
        try await manager.initialize(models: models)

        do {
            let converter = AudioConverter()
            var samples = try converter.resampleAudioFile(wavURL)
            let stats = Self.audioStats(for: samples)
            logger.debug(
                "FluidAudio ASR audio stats: samples=\(samples.count, privacy: .public) secs=\(String(format: "%.2f", stats.seconds), privacy: .public) rms=\(String(format: "%.4f", stats.rms), privacy: .public) min=\(String(format: "%.3f", stats.min), privacy: .public) max=\(String(format: "%.3f", stats.max), privacy: .public)"
            )
            if stats.rms < 0.001 {
                logger.warning("FluidAudio ASR input appears near-silent (rms=\(String(format: "%.4f", stats.rms), privacy: .public))")
            }
            let minSamples = ASRConfig.default.sampleRate
            if samples.count < minSamples {
                let padding = max(0, minSamples - samples.count)
                if padding > 0 {
                    samples.append(contentsOf: repeatElement(0, count: padding))
                    logger.debug("FluidAudio ASR padded short audio: samples=\(samples.count, privacy: .public)")
                }
            }
            let result = try await manager.transcribe(samples, source: configuration.audioSource)
            logger.debug(
                "FluidAudio ASR result: textLength=\(result.text.count, privacy: .public) confidence=\(String(format: "%.3f", result.confidence), privacy: .public) duration=\(String(format: "%.2f", result.duration), privacy: .public) processing=\(String(format: "%.2f", result.processingTime), privacy: .public) tokenTimings=\(result.tokenTimings?.count ?? 0, privacy: .public)"
            )
            let segments = FluidAudioASRSegmenter.segments(from: result)
            return TranscriptionResult(text: result.text, segments: segments)
        } catch {
            logger.error("FluidAudio ASR failed: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
            throw MinuteError.transcriptionFailed(underlyingDescription: ErrorHandler.debugMessage(for: error))
        }
    }
}

private extension FluidAudioTranscriptionService {
    static func audioStats(for samples: [Float]) -> (seconds: Double, rms: Float, min: Float, max: Float) {
        guard !samples.isEmpty else { return (0, 0, 0, 0) }
        let stride = max(1, samples.count / 100_000)
        var minValue: Float = 1
        var maxValue: Float = -1
        var sumSquares: Double = 0
        var count = 0
        var index = 0
        while index < samples.count {
            let sample = samples[index]
            minValue = min(minValue, sample)
            maxValue = max(maxValue, sample)
            sumSquares += Double(sample * sample)
            count += 1
            index += stride
        }
        let rms = count > 0 ? Float(sqrt(sumSquares / Double(count))) : 0
        let seconds = Double(samples.count) / 16_000.0
        return (seconds, rms, minValue, maxValue)
    }
}

private enum FluidAudioASRSegmenter {
    private static let maxSegmentDuration: TimeInterval = 8.0
    private static let maxSilenceGap: TimeInterval = 1.0

    static func segments(from result: ASRResult) -> [TranscriptSegment] {
        let transcript = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { return [] }

        guard let timings = result.tokenTimings, !timings.isEmpty else {
            let end = max(0, result.duration)
            return [
                TranscriptSegment(startSeconds: 0, endSeconds: end, text: transcript),
            ]
        }

        var segments: [TranscriptSegment] = []
        segments.reserveCapacity(max(1, timings.count / 8))

        var currentTokens: [TokenTiming] = []
        var segmentStart: TimeInterval = 0
        var lastEnd: TimeInterval = 0

        for timing in timings {
            if currentTokens.isEmpty {
                segmentStart = timing.startTime
            } else {
                let gap = timing.startTime - lastEnd
                let duration = timing.endTime - segmentStart
                if gap >= maxSilenceGap || duration >= maxSegmentDuration {
                    appendSegment(tokens: currentTokens, start: segmentStart, end: lastEnd, into: &segments)
                    currentTokens = []
                    segmentStart = timing.startTime
                }
            }

            currentTokens.append(timing)
            lastEnd = max(lastEnd, timing.endTime)

            if shouldEndSentence(token: timing.token) {
                appendSegment(tokens: currentTokens, start: segmentStart, end: lastEnd, into: &segments)
                currentTokens = []
            }
        }

        if !currentTokens.isEmpty {
            appendSegment(tokens: currentTokens, start: segmentStart, end: lastEnd, into: &segments)
        }

        return segments
    }

    private static func appendSegment(
        tokens: [TokenTiming],
        start: TimeInterval,
        end: TimeInterval,
        into segments: inout [TranscriptSegment]
    ) {
        let text = tokens.map(\.token).joined().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        segments.append(
            TranscriptSegment(
                startSeconds: max(0, start),
                endSeconds: max(0, end),
                text: text
            )
        )
    }

    private static func shouldEndSentence(token: String) -> Bool {
        if token.contains("\n") || token.contains("\r") {
            return true
        }

        return token.contains(".") || token.contains("?") || token.contains("!")
    }
}

private actor FluidAudioASRModelCache {
    static let shared = FluidAudioASRModelCache()
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
