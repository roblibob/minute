import XCTest
@testable import MinuteCore

final class ScreenContextTimestampNormalizerTests: XCTestCase {
    func testNormalizeUsesFirstTimestampAndOffset() {
        let result = ScreenContextTimestampNormalizer.normalize(
            rawSeconds: 12.0,
            firstTimestampSeconds: 10.0,
            offsetSeconds: 5.0
        )

        XCTAssertEqual(result, 7.0)
    }

    func testNormalizeUsesRawWhenFirstIsNil() {
        let result = ScreenContextTimestampNormalizer.normalize(
            rawSeconds: 3.0,
            firstTimestampSeconds: nil,
            offsetSeconds: 0.0
        )

        XCTAssertEqual(result, 0.0)
    }

    func testNormalizeClampsNegativeDelta() {
        let result = ScreenContextTimestampNormalizer.normalize(
            rawSeconds: 2.0,
            firstTimestampSeconds: 5.0,
            offsetSeconds: 1.0
        )

        XCTAssertEqual(result, 1.0)
    }
}
