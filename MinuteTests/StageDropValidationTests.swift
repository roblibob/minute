import Foundation
import Testing
@testable import Minute

@MainActor
struct SessionDropValidationTests {
    @Test
    func isSupportedMediaURL_supportsWavAndWave() {
        #expect(SessionMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test.wav")))
        #expect(SessionMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test.WAV")))
        #expect(SessionMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test.wave")))
        #expect(SessionMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test. wave")))
    }

    @Test
    func isSupportedMediaURL_supportsCommonAudioAndVideo() {
        #expect(SessionMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test.mp3")))
        #expect(SessionMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test.m4a")))
        #expect(SessionMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test.aiff")))
        #expect(SessionMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test.mov")))
        #expect(SessionMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test.mp4")))
    }

    @Test
    func isSupportedMediaURL_rejectsUnsupportedOrMissingExtensions() {
        #expect(!SessionMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test.txt")))
        #expect(!SessionMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test")))
        #expect(!SessionMediaValidation.isSupportedMediaURL(URL(fileURLWithPath: "/tmp/test.")))
    }
}
