import XCTest
@testable import MinuteCore

final class LiveAudioTranscriptionQueueTests: XCTestCase {
    func testDropsOldestChunksWhenLagExceeded() {
        var queue = LiveAudioTranscriptionQueue(maxLagSamples: 2_000)

        queue.enqueue(LiveAudioTranscriptionChunk(samples: Array(repeating: 0, count: 1_000), endTimeSeconds: 1))
        queue.enqueue(LiveAudioTranscriptionChunk(samples: Array(repeating: 0, count: 1_000), endTimeSeconds: 2))
        queue.enqueue(LiveAudioTranscriptionChunk(samples: Array(repeating: 0, count: 1_000), endTimeSeconds: 3))

        XCTAssertEqual(queue.pendingSamples, 2_000)
        XCTAssertNotNil(queue.pop())
        XCTAssertNotNil(queue.pop())
        XCTAssertNil(queue.pop())
    }

    func testKeepsSingleChunkEvenIfItExceedsLag() {
        var queue = LiveAudioTranscriptionQueue(maxLagSamples: 1_000)
        queue.enqueue(LiveAudioTranscriptionChunk(samples: Array(repeating: 0, count: 1_500), endTimeSeconds: 1))

        XCTAssertEqual(queue.pendingSamples, 1_500)
        XCTAssertNotNil(queue.pop())
        XCTAssertNil(queue.pop())
    }
}
