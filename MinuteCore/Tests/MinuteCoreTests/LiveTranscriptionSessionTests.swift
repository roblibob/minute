import XCTest
@testable import MinuteCore

final class LiveTranscriptionSessionTests: XCTestCase {
    func testFinishReturnsLiveTranscriptSegments() async {
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

        XCTAssertEqual(result.text, "Hello live")
        XCTAssertEqual(result.segments.count, 1)
    }

    func testTickerTextReturnsRecentTranscript() async {
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
        XCTAssertEqual(ticker, "Rolling update")
    }
}

private struct StubLiveTranscriptionService: LiveTranscriptionServicing {
    let text: String

    func transcribe(samples: [Float]) async throws -> String {
        _ = samples
        return text
    }
}
