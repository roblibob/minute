import Testing
import Foundation
@testable import MinuteCore

struct LiveAudioTranscriptionQueueTests {
    @Test
    func dropsOldestChunksWhenLagExceeded() {
        var queue = LiveAudioTranscriptionQueue(maxLagSamples: 2_000)

        queue.enqueue(LiveAudioTranscriptionChunk(samples: Array(repeating: 0, count: 1_000), endTimeSeconds: 1))
        queue.enqueue(LiveAudioTranscriptionChunk(samples: Array(repeating: 0, count: 1_000), endTimeSeconds: 2))
        queue.enqueue(LiveAudioTranscriptionChunk(samples: Array(repeating: 0, count: 1_000), endTimeSeconds: 3))

        expectEqual(queue.pendingSamples, 2_000)
        #expect(queue.pop() != nil)
        #expect(queue.pop() != nil)
        #expect(queue.pop() == nil)
    }

    @Test
    func keepsSingleChunkEvenIfItExceedsLag() {
        var queue = LiveAudioTranscriptionQueue(maxLagSamples: 1_000)
        queue.enqueue(LiveAudioTranscriptionChunk(samples: Array(repeating: 0, count: 1_500), endTimeSeconds: 1))

        expectEqual(queue.pendingSamples, 1_500)
        #expect(queue.pop() != nil)
        #expect(queue.pop() == nil)
    }
}
