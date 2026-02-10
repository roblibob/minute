import Foundation

public final class StagePreferencesStore {
    private let defaults: UserDefaults
    private let meetingTypeKey: String
    private let languageProcessingKey: String
    private let microphoneEnabledKey: String
    private let systemAudioEnabledKey: String

    public init(
        defaults: UserDefaults = .standard,
        meetingTypeKey: String = AppConfiguration.Defaults.stageMeetingTypeKey,
        languageProcessingKey: String = AppConfiguration.Defaults.stageLanguageProcessingKey,
        microphoneEnabledKey: String = AppConfiguration.Defaults.stageMicrophoneEnabledKey,
        systemAudioEnabledKey: String = AppConfiguration.Defaults.stageSystemAudioEnabledKey
    ) {
        self.defaults = defaults
        self.meetingTypeKey = meetingTypeKey
        self.languageProcessingKey = languageProcessingKey
        self.microphoneEnabledKey = microphoneEnabledKey
        self.systemAudioEnabledKey = systemAudioEnabledKey
    }

    public func load() -> StagePreferences {
        let meetingTypeRaw = defaults.string(forKey: meetingTypeKey)
        let meetingType = MeetingType(rawValue: meetingTypeRaw ?? "") ?? AppConfiguration.Defaults.defaultStageMeetingType

        let languageRaw = defaults.string(forKey: languageProcessingKey)
        let languageProcessing = LanguageProcessingProfile.resolved(from: languageRaw)

        let microphoneEnabled = defaults.object(forKey: microphoneEnabledKey) as? Bool
            ?? AppConfiguration.Defaults.defaultStageMicrophoneEnabled
        let systemAudioEnabled = defaults.object(forKey: systemAudioEnabledKey) as? Bool
            ?? AppConfiguration.Defaults.defaultStageSystemAudioEnabled

        return StagePreferences(
            meetingType: meetingType,
            languageProcessing: languageProcessing,
            microphoneEnabled: microphoneEnabled,
            systemAudioEnabled: systemAudioEnabled
        )
    }

    public func save(_ preferences: StagePreferences) {
        defaults.set(preferences.meetingType.rawValue, forKey: meetingTypeKey)
        defaults.set(preferences.languageProcessing.rawValue, forKey: languageProcessingKey)
        defaults.set(preferences.microphoneEnabled, forKey: microphoneEnabledKey)
        defaults.set(preferences.systemAudioEnabled, forKey: systemAudioEnabledKey)
    }

    public func clear() {
        defaults.removeObject(forKey: meetingTypeKey)
        defaults.removeObject(forKey: languageProcessingKey)
        defaults.removeObject(forKey: microphoneEnabledKey)
        defaults.removeObject(forKey: systemAudioEnabledKey)
    }
}
