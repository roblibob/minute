import Foundation
import Testing
@testable import Minute

@MainActor
struct StageDropValidationTests {
    @Test
    func isSupportedMediaURL_supportsWavAndWave() {
        #expect(StageMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test.wav")))
        #expect(StageMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test.WAV")))
        #expect(StageMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test.wave")))
        #expect(StageMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test. wave")))
    }

    @Test
    func isSupportedMediaURL_supportsCommonAudioAndVideo() {
        #expect(StageMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test.mp3")))
        #expect(StageMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test.m4a")))
        #expect(StageMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test.aiff")))
        #expect(StageMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test.mov")))
        #expect(StageMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test.mp4")))
    }

    @Test
    func isSupportedMediaURL_rejectsUnsupportedOrMissingExtensions() {
        #expect(!StageMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test.txt")))
        #expect(!StageMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test")))
        #expect(!StageMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test.")))
    }
}
