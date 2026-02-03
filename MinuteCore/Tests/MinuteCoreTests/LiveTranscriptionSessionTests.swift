import Testing
import Foundation
@testable import MinuteCore

struct LiveTranscriptionSessionTests {
    @Test
    func finishReturnsLiveTranscriptSegments() async {
        let service = StubLiveTranscriptionService(text: "Hello live")
        let session = LiveTranscriptionSession(
            service: service,
            configuration: LiveTranscriptionConfiguration(
                sampleRateHz: 16_000,
                recordTimeoutSeconds: 0,
                phraseTimeoutSeconds: 1,
                energyThreshold: 0
            )
        )

        let samples = [Float](repeating: 0.5, count: 16_000)
        await session.append(samples: samples, endTimeSeconds: 1.0)
        let result = await session.finish(endTimeSeconds: 1.0)

        expectEqual(result.text, "Hello live")
        expectEqual(result.segments.count, 1)
    }

    @Test
    func tickerTextReturnsRecentTranscript() async {
        let service = StubLiveTranscriptionService(text: "Rolling update")
        let session = LiveTranscriptionSession(
            service: service,
            configuration: LiveTranscriptionConfiguration(
                sampleRateHz: 16_000,
                recordTimeoutSeconds: 0,
                phraseTimeoutSeconds: 1,
                energyThreshold: 0
            )
        )

        let samples = [Float](repeating: 0.5, count: 16_000)
        await session.append(samples: samples, endTimeSeconds: 1.0)

        let ticker = await session.tickerText(maxLength: 32)
        expectEqual(ticker, "Rolling update")
    }
}

private struct StubLiveTranscriptionService: LiveTranscriptionServicing {
    let text: String

    func transcribe(samples: [Float]) async throws -> String {
        _ = samples
        return text
    }
}
