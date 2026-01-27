import Foundation

public struct AppConfiguration: Sendable, Equatable {
    public struct Defaults {
        public static let vaultRootBookmarkKey = "vaultRootBookmark"
        public static let meetingsRelativePathKey = "meetingsRelativePath"
        public static let audioRelativePathKey = "audioRelativePath"
        public static let transcriptsRelativePathKey = "transcriptsRelativePath"
        public static let saveAudioKey = "saveAudio"
        public static let saveTranscriptKey = "saveTranscript"
        public static let screenContextEnabledKey = "screenContextEnabled"
        public static let screenContextSelectedWindowsKey = "screenContextSelectedWindows"
        public static let screenContextVideoImportEnabledKey = "screenContextVideoImportEnabled"
        public static let screenContextCaptureIntervalSecondsKey = "screenContextCaptureIntervalSeconds"
        public static let summarizationModelIDKey = "summarizationModelID"
        public static let transcriptionModelIDKey = "transcriptionModelID"
        public static let transcriptionBackendIDKey = "transcriptionBackendID"
        public static let fluidAudioAsrModelIDKey = "fluidAudioAsrModelID"
        public static let micActivityNotificationsEnabledKey = "micActivityNotificationsEnabled"

        public static let defaultMeetingsRelativePath = "Meetings"
        public static let defaultAudioRelativePath = "Meetings/_audio"
        public static let defaultTranscriptsRelativePath = "Meetings/_transcripts"
        public static let defaultSaveAudio = true
        public static let defaultSaveTranscript = true
        public static let defaultScreenContextEnabled = false
        public static let defaultScreenContextVideoImportEnabled = false
        public static let defaultScreenContextCaptureIntervalSeconds: TimeInterval = 60
        public static let defaultMicActivityNotificationsEnabled = true
        public static let defaultTranscriptionBackendID = TranscriptionBackend.whisper.rawValue
        public static let defaultFluidAudioAsrModelID = FluidAudioASRModelCatalog.defaultModelID
    }

    public var meetingsRelativePath: String
    public var audioRelativePath: String
    public var transcriptsRelativePath: String
    public var saveAudio: Bool
    public var saveTranscript: Bool
    public var screenContextEnabled: Bool
    public var screenContextVideoImportEnabled: Bool
    public var screenContextCaptureIntervalSeconds: TimeInterval
    public var micActivityNotificationsEnabled: Bool

    public init(defaults: UserDefaults = .standard) {
        meetingsRelativePath = Self.validatedRelativePath(
            defaults.string(forKey: Defaults.meetingsRelativePathKey),
            fallback: Defaults.defaultMeetingsRelativePath
        )
        audioRelativePath = Self.validatedRelativePath(
            defaults.string(forKey: Defaults.audioRelativePathKey),
            fallback: Defaults.defaultAudioRelativePath
        )
        transcriptsRelativePath = Self.validatedRelativePath(
            defaults.string(forKey: Defaults.transcriptsRelativePathKey),
            fallback: Defaults.defaultTranscriptsRelativePath
        )
        saveAudio = defaults.object(forKey: Defaults.saveAudioKey) as? Bool ?? Defaults.defaultSaveAudio
        saveTranscript = defaults.object(forKey: Defaults.saveTranscriptKey) as? Bool ?? Defaults.defaultSaveTranscript
        screenContextEnabled = defaults.object(forKey: Defaults.screenContextEnabledKey) as? Bool
            ?? Defaults.defaultScreenContextEnabled
        screenContextVideoImportEnabled = defaults.object(forKey: Defaults.screenContextVideoImportEnabledKey) as? Bool
            ?? Defaults.defaultScreenContextVideoImportEnabled

        let interval = defaults.object(forKey: Defaults.screenContextCaptureIntervalSecondsKey) as? Double
        let fallback = Defaults.defaultScreenContextCaptureIntervalSeconds
        let resolved = interval ?? fallback
        screenContextCaptureIntervalSeconds = resolved > 0 ? resolved : fallback

        micActivityNotificationsEnabled = defaults.object(forKey: Defaults.micActivityNotificationsEnabledKey) as? Bool
            ?? Defaults.defaultMicActivityNotificationsEnabled
    }

    public static func validatedRelativePath(_ value: String?, fallback: String) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }
}
