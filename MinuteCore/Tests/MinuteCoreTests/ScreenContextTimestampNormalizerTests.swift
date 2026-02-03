import Testing
import Foundation
@testable import MinuteCore

struct ScreenContextTimestampNormalizerTests {
    @Test
    func normalizeUsesFirstTimestampAndOffset() {
        let result = ScreenContextTimestampNormalizer.normalize(
            rawSeconds: 12.0,
            firstTimestampSeconds: 10.0,
            offsetSeconds: 5.0
        )

        expectEqual(result, 7.0)
    }

    @Test
    func normalizeUsesRawWhenFirstIsNil() {
        let result = ScreenContextTimestampNormalizer.normalize(
            rawSeconds: 3.0,
            firstTimestampSeconds: nil,
            offsetSeconds: 0.0
        )

        expectEqual(result, 0.0)
    }

    @Test
    func normalizeClampsNegativeDelta() {
        let result = ScreenContextTimestampNormalizer.normalize(
            rawSeconds: 2.0,
            firstTimestampSeconds: 5.0,
            offsetSeconds: 1.0
        )

        expectEqual(result, 1.0)
    }
}
