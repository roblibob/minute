import XCTest
@testable import MinuteCore

final class WhisperTranscriptNormalizerTests: XCTestCase {
    func testNormalizeWhisperOutput_stripsNoiseAndCollapsesBlankLines() {
        let raw = """
        \u{001B}[32m[ 12%]\u{001B}[0m
        system_info: n_threads = 8

        Hello world.


        whisper_print_timings:    sample

        This is a test.
        """

        let normalized = TranscriptNormalizer.normalizeWhisperOutput(raw)

        XCTAssertEqual(normalized, "Hello world.\n\nThis is a test.")
    }
}
