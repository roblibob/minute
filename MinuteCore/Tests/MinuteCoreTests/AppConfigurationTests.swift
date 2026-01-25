import XCTest
@testable import MinuteCore

final class AppConfigurationTests: XCTestCase {
    func testDefaults_useFallbacksWhenUnset() {
        let defaults = makeDefaults()
        let configuration = AppConfiguration(defaults: defaults)

        XCTAssertEqual(configuration.meetingsRelativePath, AppConfiguration.Defaults.defaultMeetingsRelativePath)
        XCTAssertEqual(configuration.audioRelativePath, AppConfiguration.Defaults.defaultAudioRelativePath)
        XCTAssertEqual(configuration.transcriptsRelativePath, AppConfiguration.Defaults.defaultTranscriptsRelativePath)
        XCTAssertEqual(configuration.saveAudio, AppConfiguration.Defaults.defaultSaveAudio)
        XCTAssertEqual(configuration.saveTranscript, AppConfiguration.Defaults.defaultSaveTranscript)
        XCTAssertEqual(configuration.screenContextEnabled, AppConfiguration.Defaults.defaultScreenContextEnabled)
        XCTAssertEqual(
            configuration.screenContextVideoImportEnabled,
            AppConfiguration.Defaults.defaultScreenContextVideoImportEnabled
        )
        XCTAssertEqual(
            configuration.screenContextCaptureIntervalSeconds,
            AppConfiguration.Defaults.defaultScreenContextCaptureIntervalSeconds
        )
        XCTAssertEqual(
            configuration.micActivityNotificationsEnabled,
            AppConfiguration.Defaults.defaultMicActivityNotificationsEnabled
        )
    }

    func testDefaults_normalizesEmptyRelativePaths() {
        let defaults = makeDefaults()
        defaults.set("  ", forKey: AppConfiguration.Defaults.meetingsRelativePathKey)
        defaults.set("\n", forKey: AppConfiguration.Defaults.audioRelativePathKey)
        defaults.set("\t", forKey: AppConfiguration.Defaults.transcriptsRelativePathKey)

        let configuration = AppConfiguration(defaults: defaults)

        XCTAssertEqual(configuration.meetingsRelativePath, AppConfiguration.Defaults.defaultMeetingsRelativePath)
        XCTAssertEqual(configuration.audioRelativePath, AppConfiguration.Defaults.defaultAudioRelativePath)
        XCTAssertEqual(configuration.transcriptsRelativePath, AppConfiguration.Defaults.defaultTranscriptsRelativePath)
    }

    func testDefaults_rejectsNonPositiveCaptureInterval() {
        let defaults = makeDefaults()
        defaults.set(0.0, forKey: AppConfiguration.Defaults.screenContextCaptureIntervalSecondsKey)

        let configuration = AppConfiguration(defaults: defaults)

        XCTAssertEqual(
            configuration.screenContextCaptureIntervalSeconds,
            AppConfiguration.Defaults.defaultScreenContextCaptureIntervalSeconds
        )
    }

    func testDefaults_readsMicActivityNotificationsEnabled() {
        let defaults = makeDefaults()
        defaults.set(false, forKey: AppConfiguration.Defaults.micActivityNotificationsEnabledKey)

        let configuration = AppConfiguration(defaults: defaults)

        XCTAssertEqual(configuration.micActivityNotificationsEnabled, false)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppConfigurationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
