import Foundation

public struct StagePreferences: Codable, Sendable, Equatable {
    public var meetingType: MeetingType
    public var languageProcessing: LanguageProcessingProfile
    public var microphoneEnabled: Bool
    public var systemAudioEnabled: Bool

    public init(
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        microphoneEnabled: Bool,
        systemAudioEnabled: Bool
    ) {
        self.meetingType = meetingType
        self.languageProcessing = languageProcessing
        self.microphoneEnabled = microphoneEnabled
        self.systemAudioEnabled = systemAudioEnabled
    }

    public static var `default`: StagePreferences {
        StagePreferences(
            meetingType: AppConfiguration.Defaults.defaultStageMeetingType,
            languageProcessing: AppConfiguration.Defaults.defaultStageLanguageProcessing,
            microphoneEnabled: AppConfiguration.Defaults.defaultStageMicrophoneEnabled,
            systemAudioEnabled: AppConfiguration.Defaults.defaultStageSystemAudioEnabled
        )
    }
}
