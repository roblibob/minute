import Foundation

public struct LiveAudioStreamMixerConfiguration: Sendable, Equatable {
    public var targetSampleRateHz: Double
    public var maxChunkSamples: Int

    public init(targetSampleRateHz: Double = 16_000, maxChunkSeconds: Double = 0.5) {
        self.targetSampleRateHz = targetSampleRateHz
        self.maxChunkSamples = max(1, Int(targetSampleRateHz * maxChunkSeconds))
    }
}

public actor LiveAudioStreamMixer: LiveAudioChunkSinking {
    private let transcriptionSession: LiveTranscriptionSession
    private let config: LiveAudioStreamMixerConfiguration
    private var startedAt: Date?
    private var micQueue: [Float] = []
    private var micQueueStart: Int = 0
    private var systemQueue: [Float] = []
    private var systemQueueStart: Int = 0
    private var micOffsetSamples: Int?
    private var systemOffsetSamples: Int?
    private var mixedSampleCursor: Int = 0
    private var appendTask: Task<Void, Never>?

    public init(
        transcriptionSession: LiveTranscriptionSession,
        configuration: LiveAudioStreamMixerConfiguration = LiveAudioStreamMixerConfiguration()
    ) {
        self.transcriptionSession = transcriptionSession
        self.config = configuration
    }

    public func start(at startTime: Date) async {
        startedAt = startTime
        micQueue = []
        micQueueStart = 0
        systemQueue = []
        systemQueueStart = 0
        micOffsetSamples = nil
        systemOffsetSamples = nil
        mixedSampleCursor = 0
        appendTask = nil
        await transcriptionSession.reset()
    }

    public func stop() async -> TranscriptionResult {
        drainAvailableSamples()

        if let pending = appendTask {
            appendTask = nil
            pending.cancel()
            _ = await waitForAppendTask(pending, timeoutNanos: 1_000_000_000)
        }

        let endSeconds = Double(mixedSampleCursor) / config.targetSampleRateHz
        return await transcriptionSession.finish(endTimeSeconds: endSeconds)
    }

    public func handleAudioChunk(_ chunk: LiveAudioChunk) async {
        guard let startedAt else { return }

        let offsetSeconds = max(0, chunk.capturedAt.timeIntervalSince(startedAt))
        let offsetSamples = Int((offsetSeconds * config.targetSampleRateHz).rounded())
        let resampled = resample(samples: chunk.samples, fromRateHz: chunk.sampleRateHz)

        if resampled.isEmpty {
            return
        }

        switch chunk.source {
        case .microphone:
            if micOffsetSamples == nil {
                micOffsetSamples = offsetSamples
            }
            micQueue.append(contentsOf: resampled)
        case .system:
            if systemOffsetSamples == nil {
                systemOffsetSamples = offsetSamples
            }
            systemQueue.append(contentsOf: resampled)
        }

        drainAvailableSamples()
    }

    private func drainAvailableSamples() {
        let micAvailable = availableSamples(offsetSamples: micOffsetSamples, queue: micQueue, start: micQueueStart)
        let systemAvailable = availableSamples(offsetSamples: systemOffsetSamples, queue: systemQueue, start: systemQueueStart)
        let available: Int
        switch (micOffsetSamples, systemOffsetSamples) {
        case (.some, .some):
            available = min(micAvailable, systemAvailable)
        case (.some, .none):
            available = micAvailable
        case (.none, .some):
            available = systemAvailable
        case (.none, .none):
            return
        }

        guard available > mixedSampleCursor else { return }

        var remaining = available - mixedSampleCursor
        while remaining > 0 {
            let count = min(remaining, config.maxChunkSamples)
            let mixed = mixSamples(startIndex: mixedSampleCursor, count: count)
            mixedSampleCursor += count
            remaining -= count
            trimQueues()

            let endSeconds = Double(mixedSampleCursor) / config.targetSampleRateHz
            enqueueTranscription(samples: mixed, endTimeSeconds: endSeconds)
        }
    }

    private func enqueueTranscription(samples: [Float], endTimeSeconds: TimeInterval) {
        let session = transcriptionSession
        let previous = appendTask
        appendTask = Task {
            if let previous {
                if Task.isCancelled { return }
                _ = await previous.value
            }
            if Task.isCancelled { return }
            await session.append(samples: samples, endTimeSeconds: endTimeSeconds)
        }
    }

    private func waitForAppendTask(_ task: Task<Void, Never>, timeoutNanos: UInt64) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                _ = await task.value
                return true
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanos)
                return false
            }
            let completed = await group.next() ?? false
            group.cancelAll()
            return completed
        }
    }

    private func mixSamples(startIndex: Int, count: Int) -> [Float] {
        var output = [Float](repeating: 0, count: count)

        if let micOffsetSamples {
            for i in 0..<count {
                let timelineIndex = startIndex + i
                let micIndex = timelineIndex - micOffsetSamples
                if micIndex >= 0 {
                    let queueIndex = micQueueStart + micIndex
                    if queueIndex >= micQueueStart, queueIndex < micQueue.count {
                        output[i] += micQueue[queueIndex]
                    }
                }
            }
        }

        if let systemOffsetSamples {
            for i in 0..<count {
                let timelineIndex = startIndex + i
                let systemIndex = timelineIndex - systemOffsetSamples
                if systemIndex >= 0 {
                    let queueIndex = systemQueueStart + systemIndex
                    if queueIndex >= systemQueueStart, queueIndex < systemQueue.count {
                        output[i] += systemQueue[queueIndex]
                    }
                }
            }
        }

        for i in 0..<count {
            let sample = output[i]
            if sample > 1 {
                output[i] = 1
            } else if sample < -1 {
                output[i] = -1
            }
        }

        return output
    }

    private func trimQueues() {
        trimQueue(&micQueue, startIndex: &micQueueStart, offsetSamples: &micOffsetSamples)
        trimQueue(&systemQueue, startIndex: &systemQueueStart, offsetSamples: &systemOffsetSamples)
    }

    private func trimQueue(_ queue: inout [Float], startIndex: inout Int, offsetSamples: inout Int?) {
        guard var offset = offsetSamples else { return }
        let available = max(0, mixedSampleCursor - offset)
        let drop = min(available, queue.count - startIndex)
        guard drop > 0 else { return }
        startIndex += drop
        offset += drop
        offsetSamples = offset

        if startIndex > 8_192 {
            queue.removeFirst(startIndex)
            startIndex = 0
        }
    }

    private func availableSamples(offsetSamples: Int?, queue: [Float], start: Int) -> Int {
        guard let offsetSamples else { return 0 }
        let count = max(0, queue.count - start)
        return offsetSamples + count
    }

    private func resample(samples: [Float], fromRateHz: Double) -> [Float] {
        guard fromRateHz > 0 else { return [] }
        if abs(fromRateHz - config.targetSampleRateHz) < 0.0001 {
            return samples
        }

        let ratio = config.targetSampleRateHz / fromRateHz
        let outputCount = max(1, Int(Double(samples.count) * ratio))
        var output = [Float](repeating: 0, count: outputCount)
        let step = fromRateHz / config.targetSampleRateHz

        for i in 0..<outputCount {
            let position = Double(i) * step
            let index = Int(position)
            let nextIndex = min(index + 1, samples.count - 1)
            let frac = Float(position - Double(index))
            let s0 = samples[min(index, samples.count - 1)]
            let s1 = samples[nextIndex]
            output[i] = s0 + (s1 - s0) * frac
        }

        return output
    }
}
