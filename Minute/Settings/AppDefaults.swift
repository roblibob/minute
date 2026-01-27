import MinuteCore

enum AppDefaultsKey {
    static let saveAudio = AppConfiguration.Defaults.saveAudioKey
    static let saveTranscript = AppConfiguration.Defaults.saveTranscriptKey
    static let screenContextEnabled = AppConfiguration.Defaults.screenContextEnabledKey
    static let screenContextSelectedWindows = AppConfiguration.Defaults.screenContextSelectedWindowsKey
    static let screenContextVideoImportEnabled = AppConfiguration.Defaults.screenContextVideoImportEnabledKey
    static let screenContextCaptureIntervalSeconds = AppConfiguration.Defaults.screenContextCaptureIntervalSecondsKey
    static let transcriptionModelID = AppConfiguration.Defaults.transcriptionModelIDKey
    static let transcriptionBackendID = AppConfiguration.Defaults.transcriptionBackendIDKey
    static let fluidAudioAsrModelID = AppConfiguration.Defaults.fluidAudioAsrModelIDKey
    static let micActivityNotificationsEnabled = AppConfiguration.Defaults.micActivityNotificationsEnabledKey
}
