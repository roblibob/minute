import Foundation

public struct AppConfiguration: Sendable, Equatable {
    public struct Defaults {
        public static let vaultRootBookmarkKey = "vaultRootBookmark"
        public static let vaultRootPathDisplayKey = "vaultRootPathDisplay"
        public static let meetingsRelativePathKey = "meetingsRelativePath"
        public static let audioRelativePathKey = "audioRelativePath"
        public static let transcriptsRelativePathKey = "transcriptsRelativePath"
        public static let saveAudioKey = "saveAudio"
        public static let saveTranscriptKey = "saveTranscript"
        public static let normalizeAnalysisAudioKey = "normalizeAnalysisAudio"
        public static let screenContextEnabledKey = "screenContextEnabled"
        public static let screenContextSelectedWindowsKey = "screenContextSelectedWindows"
        public static let screenContextVideoImportEnabledKey = "screenContextVideoImportEnabled"
        public static let screenContextCaptureIntervalSecondsKey = "screenContextCaptureIntervalSeconds"
        public static let summarizationModelIDKey = "summarizationModelID"
        public static let summarizationProviderIDKey = "summarizationProviderID"
        public static let summarizationOllamaModelTagKey = "summarizationOllamaModelTag"
        public static let summarizationLMStudioModelIdentifierKey = "summarizationLMStudioModelIdentifier"
        public static let ollamaBaseURLKey = "ollamaBaseURL"
        public static let lmStudioBaseURLKey = "lmStudioBaseURL"
        public static let summarizationContextWindowPresetKey = "summarizationContextWindowPreset"
        public static let visionProviderIDKey = "visionProviderID"
        public static let visionBuiltInModelIDKey = "visionBuiltInModelID"
        public static let visionOllamaModelTagKey = "visionOllamaModelTag"
        public static let visionLMStudioModelIdentifierKey = "visionLMStudioModelIdentifier"
        public static let transcriptionModelIDKey = "transcriptionModelID"
        public static let transcriptionBackendIDKey = "transcriptionBackendID"
        public static let fluidAudioAsrModelIDKey = "fluidAudioAsrModelID"
        public static let micActivityNotificationsEnabledKey = "micActivityNotificationsEnabled"
        public static let knownSpeakerSuggestionsEnabledKey = "knownSpeakerSuggestionsEnabled"
        public static let outputLanguageKey = "outputLanguage"
        public static let transcriptionLanguageKey = "transcriptionLanguage"
        public static let vocabularyBoostingEnabledKey = "vocabularyBoostingEnabled"
        public static let vocabularyBoostingTermsKey = "vocabularyBoostingTerms"
        public static let vocabularyBoostingStrengthKey = "vocabularyBoostingStrength"
        public static let vocabularyBoostingUpdatedAtKey = "vocabularyBoostingUpdatedAt"

        public static let stageMeetingTypeKey = "stageMeetingType"
        public static let stageMeetingTypeIDKey = "stageMeetingTypeID"
        public static let stageLanguageProcessingKey = "stageLanguageProcessing"
        public static let stageMicrophoneEnabledKey = "stageMicrophoneEnabled"
        public static let stageSystemAudioEnabledKey = "stageSystemAudioEnabled"

        public static let defaultMeetingsRelativePath = "Meetings"
        public static let defaultAudioRelativePath = "Meetings/_audio"
        public static let defaultTranscriptsRelativePath = "Meetings/_transcripts"
        public static let defaultSaveAudio = true
        public static let defaultSaveTranscript = true
        public static let defaultNormalizeAnalysisAudio = true
        public static let defaultScreenContextEnabled = false
        public static let defaultScreenContextVideoImportEnabled = false
        public static let defaultScreenContextCaptureIntervalSeconds: TimeInterval = 60
        public static let defaultOllamaBaseURL = "http://127.0.0.1:11434"
        public static let defaultLMStudioBaseURL = "http://127.0.0.1:1234"
        public static let defaultMicActivityNotificationsEnabled = true
        public static let defaultKnownSpeakerSuggestionsEnabled = false
        public static let defaultOutputLanguage = OutputLanguage.defaultSelection
        public static let defaultSummarizationProviderID = InferenceProvider.builtIn.rawValue
        public static let defaultVisionProviderID = InferenceProvider.builtIn.rawValue
        public static let defaultVisionBuiltInModelID = SummarizationModelCatalog.defaultModelID
        public static let defaultSummarizationContextWindowPreset = SummarizationContextWindowPreset.balanced
        public static let defaultTranscriptionBackendID = TranscriptionBackend.whisper.rawValue
        public static let defaultFluidAudioAsrModelID = FluidAudioASRModelCatalog.defaultModelID
        public static let defaultVocabularyBoostingEnabled = false
        public static let defaultVocabularyBoostingStrength = VocabularyBoostingStrength.balanced
        public static let defaultTranscriptionLanguage = TranscriptionLanguage.defaultSelection

        public static let defaultStageMeetingType = MeetingType.autodetect
        public static let defaultStageMeetingTypeID = MeetingType.autodetect.rawValue
        public static let defaultStageLanguageProcessing = LanguageProcessingProfile.autoToEnglish
        public static let defaultStageMicrophoneEnabled = true
        public static let defaultStageSystemAudioEnabled = true
    }

    public var meetingsRelativePath: String
    public var audioRelativePath: String
    public var transcriptsRelativePath: String
    public var saveAudio: Bool
    public var saveTranscript: Bool
    public var normalizeAnalysisAudio: Bool
    public var screenContextEnabled: Bool
    public var screenContextVideoImportEnabled: Bool
    public var screenContextCaptureIntervalSeconds: TimeInterval
    public var summarizationProviderID: String
    public var summarizationOllamaModelTag: String?
    public var summarizationLMStudioModelIdentifier: String?
    public var ollamaBaseURL: String
    public var lmStudioBaseURL: String
    public var visionProviderID: String
    public var visionBuiltInModelID: String
    public var visionOllamaModelTag: String?
    public var visionLMStudioModelIdentifier: String?
    public var micActivityNotificationsEnabled: Bool
    public var knownSpeakerSuggestionsEnabled: Bool
    public var vocabularyBoostingEnabled: Bool
    public var vocabularyBoostingTerms: [String]
    public var vocabularyBoostingStrength: VocabularyBoostingStrength

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
        normalizeAnalysisAudio = defaults.object(forKey: Defaults.normalizeAnalysisAudioKey) as? Bool
            ?? Defaults.defaultNormalizeAnalysisAudio
        screenContextEnabled = defaults.object(forKey: Defaults.screenContextEnabledKey) as? Bool
            ?? Defaults.defaultScreenContextEnabled
        screenContextVideoImportEnabled = defaults.object(forKey: Defaults.screenContextVideoImportEnabledKey) as? Bool
            ?? Defaults.defaultScreenContextVideoImportEnabled

        let interval = defaults.object(forKey: Defaults.screenContextCaptureIntervalSecondsKey) as? Double
        let fallback = Defaults.defaultScreenContextCaptureIntervalSeconds
        let resolved = interval ?? fallback
        screenContextCaptureIntervalSeconds = resolved > 0 ? resolved : fallback
        let summarizationProviderRaw = defaults.string(forKey: Defaults.summarizationProviderIDKey)
            ?? Defaults.defaultSummarizationProviderID
        summarizationProviderID = InferenceProvider(rawValue: summarizationProviderRaw)?.rawValue
            ?? Defaults.defaultSummarizationProviderID
        summarizationOllamaModelTag = Self.normalizedOptionalString(
            defaults.string(forKey: Defaults.summarizationOllamaModelTagKey)
        )
        summarizationLMStudioModelIdentifier = Self.normalizedOptionalString(
            defaults.string(forKey: Defaults.summarizationLMStudioModelIdentifierKey)
        )
        ollamaBaseURL = Self.validatedLocalServerBaseURL(
            defaults.string(forKey: Defaults.ollamaBaseURLKey),
            fallback: Defaults.defaultOllamaBaseURL
        )
        lmStudioBaseURL = Self.validatedLocalServerBaseURL(
            defaults.string(forKey: Defaults.lmStudioBaseURLKey),
            fallback: Defaults.defaultLMStudioBaseURL
        )
        let visionProviderRaw = defaults.string(forKey: Defaults.visionProviderIDKey)
            ?? Defaults.defaultVisionProviderID
        visionProviderID = InferenceProvider(rawValue: visionProviderRaw)?.rawValue
            ?? Defaults.defaultVisionProviderID
        let visionModelID = defaults.string(forKey: Defaults.visionBuiltInModelIDKey)
        visionBuiltInModelID = SummarizationModelCatalog.model(for: visionModelID)?.id
            ?? Defaults.defaultVisionBuiltInModelID
        visionOllamaModelTag = Self.normalizedOptionalString(
            defaults.string(forKey: Defaults.visionOllamaModelTagKey)
        )
        visionLMStudioModelIdentifier = Self.normalizedOptionalString(
            defaults.string(forKey: Defaults.visionLMStudioModelIdentifierKey)
        )

        micActivityNotificationsEnabled = defaults.object(forKey: Defaults.micActivityNotificationsEnabledKey) as? Bool
            ?? Defaults.defaultMicActivityNotificationsEnabled

        knownSpeakerSuggestionsEnabled = defaults.object(forKey: Defaults.knownSpeakerSuggestionsEnabledKey) as? Bool
            ?? Defaults.defaultKnownSpeakerSuggestionsEnabled

        vocabularyBoostingEnabled = defaults.object(forKey: Defaults.vocabularyBoostingEnabledKey) as? Bool
            ?? Defaults.defaultVocabularyBoostingEnabled
        vocabularyBoostingTerms = VocabularyTermEntry.normalizeDisplayTerms(
            defaults.stringArray(forKey: Defaults.vocabularyBoostingTermsKey) ?? []
        )
        let strengthRaw = defaults.string(forKey: Defaults.vocabularyBoostingStrengthKey) ?? ""
        vocabularyBoostingStrength = VocabularyBoostingStrength(rawValue: strengthRaw)
            ?? Defaults.defaultVocabularyBoostingStrength
    }

    public static func validatedRelativePath(_ value: String?, fallback: String) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }

    public static func validatedOllamaBaseURL(_ value: String?, fallback: String) -> String {
        validatedLocalServerBaseURL(value, fallback: fallback)
    }

    public static func validatedLocalServerBaseURL(_ value: String?, fallback: String) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            return fallback
        }

        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }

        return components.string ?? trimmed
    }

    private static func normalizedOptionalString(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
