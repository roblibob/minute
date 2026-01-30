import Foundation
import os

public enum LiveAudioSource: Sendable {
    case microphone
    case system
}

public struct LiveAudioChunk: Sendable {
    public var source: LiveAudioSource
    public var samples: [Float]
    public var sampleRateHz: Double
    public var capturedAt: Date

    public init(source: LiveAudioSource, samples: [Float], sampleRateHz: Double, capturedAt: Date) {
        self.source = source
        self.samples = samples
        self.sampleRateHz = sampleRateHz
        self.capturedAt = capturedAt
    }
}

public protocol LiveAudioChunkSinking: Sendable {
    func handleAudioChunk(_ chunk: LiveAudioChunk) async
}

public protocol LiveTranscriptionServicing: Sendable {
    func transcribe(samples: [Float]) async throws -> String
}

public struct LiveTranscriptionConfiguration: Sendable, Equatable {
    public var sampleRateHz: Double
    public var recordTimeoutSeconds: TimeInterval
    public var phraseTimeoutSeconds: TimeInterval
    public var energyThreshold: Float
    public var maxPhraseSeconds: TimeInterval

    public init(
        sampleRateHz: Double = 16_000,
        recordTimeoutSeconds: TimeInterval = 2.0,
        phraseTimeoutSeconds: TimeInterval = 3.0,
        energyThreshold: Float = 0.01,
        maxPhraseSeconds: TimeInterval = 10.0
    ) {
        self.sampleRateHz = sampleRateHz
        self.recordTimeoutSeconds = recordTimeoutSeconds
        self.phraseTimeoutSeconds = phraseTimeoutSeconds
        self.energyThreshold = energyThreshold
        self.maxPhraseSeconds = max(0, maxPhraseSeconds)
    }
}

public actor LiveTranscriptionSession {
    private struct Line: Sendable {
        var startSeconds: TimeInterval
        var endSeconds: TimeInterval
        var text: String
    }

    private let service: LiveTranscriptionServicing
    private let config: LiveTranscriptionConfiguration
    private let logger = Logger(subsystem: "roblibob.Minute", category: "live-transcription")

    private var lines: [Line] = []
    private var activeLineIndex: Int?
    private var currentPhraseSamples: [Float] = []
    private var lastSpeechSeconds: TimeInterval?
    private var lastTranscribeSeconds: TimeInterval?

    public init(service: LiveTranscriptionServicing, configuration: LiveTranscriptionConfiguration = LiveTranscriptionConfiguration()) {
        self.service = service
        self.config = configuration
    }

    public func reset() {
        lines = []
        activeLineIndex = nil
        currentPhraseSamples = []
        lastSpeechSeconds = nil
        lastTranscribeSeconds = nil
    }

    public func append(samples: [Float], endTimeSeconds: TimeInterval) async {
        guard !samples.isEmpty else { return }

        let chunkDuration = Double(samples.count) / config.sampleRateHz
        let chunkStartSeconds = max(0, endTimeSeconds - chunkDuration)
        let energy = rms(samples)

        if energy >= config.energyThreshold {
            let maxPhraseSamples = max(0, Int(config.maxPhraseSeconds * config.sampleRateHz))
            if maxPhraseSamples > 0, currentPhraseSamples.count + samples.count > maxPhraseSamples {
                await transcribeCurrentPhrase(endTimeSeconds: chunkStartSeconds)
                await finalizePhrase(endTimeSeconds: chunkStartSeconds)
            }

            if activeLineIndex == nil {
                activeLineIndex = lines.count
                lines.append(Line(startSeconds: chunkStartSeconds, endSeconds: endTimeSeconds, text: ""))
            }

            currentPhraseSamples.append(contentsOf: samples)
            lastSpeechSeconds = endTimeSeconds

            let shouldTranscribe: Bool
            if let lastTranscribeSeconds {
                shouldTranscribe = endTimeSeconds - lastTranscribeSeconds >= config.recordTimeoutSeconds
            } else {
                shouldTranscribe = true
            }

            if shouldTranscribe {
                lastTranscribeSeconds = endTimeSeconds
                await transcribeCurrentPhrase(endTimeSeconds: endTimeSeconds)
            }
        } else if let lastSpeechSeconds, endTimeSeconds - lastSpeechSeconds >= config.phraseTimeoutSeconds {
            await finalizePhrase(endTimeSeconds: lastSpeechSeconds)
        }
    }

    public func finish(endTimeSeconds: TimeInterval) async -> TranscriptionResult {
        if activeLineIndex != nil {
            await transcribeCurrentPhrase(endTimeSeconds: endTimeSeconds)
            await finalizePhrase(endTimeSeconds: endTimeSeconds)
        }

        let segments: [TranscriptSegment] = lines.compactMap { line in
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return TranscriptSegment(
                startSeconds: max(0, line.startSeconds),
                endSeconds: max(line.endSeconds, line.startSeconds),
                text: trimmed
            )
        }

        let text = segments.map(\.text).joined(separator: "\n")
        return TranscriptionResult(text: text, segments: segments)
    }

    public func tickerText(maxLength: Int) -> String {
        guard maxLength > 0 else { return "" }
        let parts = lines.compactMap { line in
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        let joined = parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !joined.isEmpty else { return "" }
        guard joined.count > maxLength else { return joined }
        let suffix = joined.suffix(maxLength)
        return String(suffix)
    }

    private func transcribeCurrentPhrase(endTimeSeconds: TimeInterval) async {
        guard let activeLineIndex else { return }
        guard !currentPhraseSamples.isEmpty else { return }
        if Task.isCancelled { return }

        do {
            let text = try await service.transcribe(samples: currentPhraseSamples)
            if Task.isCancelled { return }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return
            }
            lines[activeLineIndex].text = trimmed
            lines[activeLineIndex].endSeconds = endTimeSeconds
        } catch {
            let count = currentPhraseSamples.count
            logger.error("Live transcription failed (samples=\(count, privacy: .public)): \(ErrorHandler.debugMessage(for: error), privacy: .public)")
        }
    }

    private func finalizePhrase(endTimeSeconds: TimeInterval) async {
        if let activeLineIndex {
            lines[activeLineIndex].endSeconds = max(lines[activeLineIndex].endSeconds, endTimeSeconds)
        }
        activeLineIndex = nil
        currentPhraseSamples.removeAll(keepingCapacity: true)
        lastSpeechSeconds = nil
        lastTranscribeSeconds = nil
    }
}

private func rms(_ samples: [Float]) -> Float {
    guard !samples.isEmpty else { return 0 }
    var sum: Float = 0
    for sample in samples {
        sum += sample * sample
    }
    return sqrt(sum / Float(samples.count))
}
