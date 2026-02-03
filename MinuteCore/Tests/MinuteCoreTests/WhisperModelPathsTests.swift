import Testing
import Foundation
@testable import MinuteCore

struct WhisperModelPathsTests {
    @Test
    func resolvedModelURL_withAbsoluteOverride_usesOverride() {
        let absolutePath = "/tmp/whisper-model-\(UUID().uuidString).bin"
        let url = WhisperModelPaths.resolvedModelURL(
            fallback: WhisperModelPaths.defaultBaseModelURL,
            environment: ["MINUTE_WHISPER_MODEL": absolutePath]
        )
        expectEqual(url.path, absolutePath)
    }

    @Test
    func resolvedModelURL_withFilenameOverride_usesWhisperModelsFolder() {
        let filename = "ggml-large-v3-turbo.bin"
        let baseFolder = WhisperModelPaths.defaultBaseModelURL.deletingLastPathComponent()
        let url = WhisperModelPaths.resolvedModelURL(
            fallback: WhisperModelPaths.defaultBaseModelURL,
            environment: ["MINUTE_WHISPER_MODEL": filename]
        )
        expectEqual(url, baseFolder.appendingPathComponent(filename))
    }
}
