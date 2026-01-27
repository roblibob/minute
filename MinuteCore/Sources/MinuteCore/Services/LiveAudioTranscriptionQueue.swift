import Foundation

struct LiveAudioTranscriptionChunk: Sendable, Equatable {
    let samples: [Float]
    let endTimeSeconds: TimeInterval
}

struct LiveAudioTranscriptionQueue {
    private(set) var maxLagSamples: Int
    private(set) var pendingSamples: Int = 0
    private var chunks: [LiveAudioTranscriptionChunk] = []

    init(maxLagSamples: Int) {
        self.maxLagSamples = max(0, maxLagSamples)
    }

    var isEmpty: Bool {
        chunks.isEmpty
    }

    mutating func enqueue(_ chunk: LiveAudioTranscriptionChunk) {
        chunks.append(chunk)
        pendingSamples += chunk.samples.count
        dropIfNeeded()
    }

    mutating func pop() -> LiveAudioTranscriptionChunk? {
        guard !chunks.isEmpty else { return nil }
        let chunk = chunks.removeFirst()
        pendingSamples = max(0, pendingSamples - chunk.samples.count)
        return chunk
    }

    mutating func removeAll() {
        chunks.removeAll()
        pendingSamples = 0
    }

    private mutating func dropIfNeeded() {
        guard maxLagSamples > 0 else { return }
        while pendingSamples > maxLagSamples, chunks.count > 1 {
            let dropped = chunks.removeFirst()
            pendingSamples = max(0, pendingSamples - dropped.samples.count)
        }
    }
}
