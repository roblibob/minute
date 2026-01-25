import XCTest
@testable import MinuteCore

final class WhisperModelPathsTests: XCTestCase {
    func testResolvedModelURL_withAbsoluteOverride_usesOverride() {
        let absolutePath = "/tmp/whisper-model-\(UUID().uuidString).bin"
        let url = WhisperModelPaths.resolvedModelURL(
            fallback: WhisperModelPaths.defaultBaseModelURL,
            environment: ["MINUTE_WHISPER_MODEL": absolutePath]
        )
        XCTAssertEqual(url.path, absolutePath)
    }

    func testResolvedModelURL_withFilenameOverride_usesWhisperModelsFolder() {
        let filename = "ggml-large-v3-turbo.bin"
        let baseFolder = WhisperModelPaths.defaultBaseModelURL.deletingLastPathComponent()
        let url = WhisperModelPaths.resolvedModelURL(
            fallback: WhisperModelPaths.defaultBaseModelURL,
            environment: ["MINUTE_WHISPER_MODEL": filename]
        )
        XCTAssertEqual(url, baseFolder.appendingPathComponent(filename))
    }
}
