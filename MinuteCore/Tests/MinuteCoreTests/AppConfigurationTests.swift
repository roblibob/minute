import Testing
import Foundation
@testable import MinuteCore

struct AppConfigurationTests {
    @Test
    func defaults_useFallbacksWhenUnset() {
        let defaults = makeDefaults()
        let configuration = AppConfiguration(defaults: defaults)

        expectEqual(configuration.meetingsRelativePath, AppConfiguration.Defaults.defaultMeetingsRelativePath)
        expectEqual(configuration.audioRelativePath, AppConfiguration.Defaults.defaultAudioRelativePath)
        expectEqual(configuration.transcriptsRelativePath, AppConfiguration.Defaults.defaultTranscriptsRelativePath)
        expectEqual(configuration.saveAudio, AppConfiguration.Defaults.defaultSaveAudio)
        expectEqual(configuration.saveTranscript, AppConfiguration.Defaults.defaultSaveTranscript)
        expectEqual(configuration.screenContextEnabled, AppConfiguration.Defaults.defaultScreenContextEnabled)
        expectEqual(
            configuration.screenContextVideoImportEnabled,
            AppConfiguration.Defaults.defaultScreenContextVideoImportEnabled
        )
        expectEqual(
            configuration.screenContextCaptureIntervalSeconds,
            AppConfiguration.Defaults.defaultScreenContextCaptureIntervalSeconds
        )
        expectEqual(
            configuration.micActivityNotificationsEnabled,
            AppConfiguration.Defaults.defaultMicActivityNotificationsEnabled
        )
    }

    @Test
    func defaults_normalizesEmptyRelativePaths() {
        let defaults = makeDefaults()
        defaults.set("  ", forKey: AppConfiguration.Defaults.meetingsRelativePathKey)
        defaults.set("\n", forKey: AppConfiguration.Defaults.audioRelativePathKey)
        defaults.set("\t", forKey: AppConfiguration.Defaults.transcriptsRelativePathKey)

        let configuration = AppConfiguration(defaults: defaults)

        expectEqual(configuration.meetingsRelativePath, AppConfiguration.Defaults.defaultMeetingsRelativePath)
        expectEqual(configuration.audioRelativePath, AppConfiguration.Defaults.defaultAudioRelativePath)
        expectEqual(configuration.transcriptsRelativePath, AppConfiguration.Defaults.defaultTranscriptsRelativePath)
    }

    @Test
    func defaults_rejectsNonPositiveCaptureInterval() {
        let defaults = makeDefaults()
        defaults.set(0.0, forKey: AppConfiguration.Defaults.screenContextCaptureIntervalSecondsKey)

        let configuration = AppConfiguration(defaults: defaults)

        expectEqual(
            configuration.screenContextCaptureIntervalSeconds,
            AppConfiguration.Defaults.defaultScreenContextCaptureIntervalSeconds
        )
    }

    @Test
    func defaults_readsMicActivityNotificationsEnabled() {
        let defaults = makeDefaults()
        defaults.set(false, forKey: AppConfiguration.Defaults.micActivityNotificationsEnabledKey)

        let configuration = AppConfiguration(defaults: defaults)

        expectEqual(configuration.micActivityNotificationsEnabled, false)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppConfigurationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
