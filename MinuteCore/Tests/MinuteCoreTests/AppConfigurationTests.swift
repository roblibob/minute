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
        expectEqual(configuration.normalizeAnalysisAudio, AppConfiguration.Defaults.defaultNormalizeAnalysisAudio)
        expectEqual(configuration.screenContextEnabled, AppConfiguration.Defaults.defaultScreenContextEnabled)
        expectEqual(
            configuration.screenContextVideoImportEnabled,
            AppConfiguration.Defaults.defaultScreenContextVideoImportEnabled
        )
        expectEqual(
            configuration.screenContextCaptureIntervalSeconds,
            AppConfiguration.Defaults.defaultScreenContextCaptureIntervalSeconds
        )
        expectEqual(configuration.summarizationProviderID, AppConfiguration.Defaults.defaultSummarizationProviderID)
        expectEqual(configuration.summarizationOllamaModelTag, nil)
        expectEqual(configuration.summarizationLMStudioModelIdentifier, nil)
        expectEqual(configuration.ollamaBaseURL, AppConfiguration.Defaults.defaultOllamaBaseURL)
        expectEqual(configuration.lmStudioBaseURL, AppConfiguration.Defaults.defaultLMStudioBaseURL)
        expectEqual(configuration.visionProviderID, AppConfiguration.Defaults.defaultVisionProviderID)
        expectEqual(configuration.visionBuiltInModelID, AppConfiguration.Defaults.defaultVisionBuiltInModelID)
        expectEqual(configuration.visionOllamaModelTag, nil)
        expectEqual(configuration.visionLMStudioModelIdentifier, nil)
        expectEqual(
            configuration.micActivityNotificationsEnabled,
            AppConfiguration.Defaults.defaultMicActivityNotificationsEnabled
        )
        expectEqual(
            configuration.vocabularyBoostingEnabled,
            AppConfiguration.Defaults.defaultVocabularyBoostingEnabled
        )
        expectEqual(configuration.vocabularyBoostingTerms, [])
        expectEqual(
            configuration.vocabularyBoostingStrength,
            AppConfiguration.Defaults.defaultVocabularyBoostingStrength
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

    @Test
    func defaults_readsNormalizeAnalysisAudio() {
        let defaults = makeDefaults()
        defaults.set(false, forKey: AppConfiguration.Defaults.normalizeAnalysisAudioKey)

        let configuration = AppConfiguration(defaults: defaults)

        expectEqual(configuration.normalizeAnalysisAudio, false)
    }

    @Test
    func defaults_readsVocabularyBoostingSettings() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: AppConfiguration.Defaults.vocabularyBoostingEnabledKey)
        defaults.set(["  Acme  ", "ACME", "Roadmap"], forKey: AppConfiguration.Defaults.vocabularyBoostingTermsKey)
        defaults.set(VocabularyBoostingStrength.aggressive.rawValue, forKey: AppConfiguration.Defaults.vocabularyBoostingStrengthKey)

        let configuration = AppConfiguration(defaults: defaults)

        expectEqual(configuration.vocabularyBoostingEnabled, true)
        expectEqual(configuration.vocabularyBoostingTerms, ["Acme", "Roadmap"])
        expectEqual(configuration.vocabularyBoostingStrength, .aggressive)
    }

    @Test
    func defaults_normalizesInferenceConfiguration() {
        let defaults = makeDefaults()
        defaults.set("invalid", forKey: AppConfiguration.Defaults.summarizationProviderIDKey)
        defaults.set("lmStudio", forKey: AppConfiguration.Defaults.visionProviderIDKey)
        defaults.set("   llama3.2-vision   ", forKey: AppConfiguration.Defaults.visionOllamaModelTagKey)
        defaults.set("   ", forKey: AppConfiguration.Defaults.summarizationOllamaModelTagKey)
        defaults.set("   qwen2.5-vl-instruct   ", forKey: AppConfiguration.Defaults.visionLMStudioModelIdentifierKey)
        defaults.set("missing-model", forKey: AppConfiguration.Defaults.visionBuiltInModelIDKey)
        defaults.set("  http://192.168.1.20:11434  ", forKey: AppConfiguration.Defaults.ollamaBaseURLKey)
        defaults.set("  http://127.0.0.1:1234  ", forKey: AppConfiguration.Defaults.lmStudioBaseURLKey)

        let configuration = AppConfiguration(defaults: defaults)

        expectEqual(configuration.summarizationProviderID, AppConfiguration.Defaults.defaultSummarizationProviderID)
        expectEqual(configuration.visionProviderID, InferenceProvider.lmStudio.rawValue)
        expectEqual(configuration.summarizationOllamaModelTag, nil)
        expectEqual(configuration.visionOllamaModelTag, "llama3.2-vision")
        expectEqual(configuration.visionLMStudioModelIdentifier, "qwen2.5-vl-instruct")
        expectEqual(configuration.visionBuiltInModelID, AppConfiguration.Defaults.defaultVisionBuiltInModelID)
        expectEqual(configuration.ollamaBaseURL, "http://192.168.1.20:11434")
        expectEqual(configuration.lmStudioBaseURL, "http://127.0.0.1:1234")
    }

    @Test
    func defaults_fallsBackForInvalidOllamaBaseURL() {
        let defaults = makeDefaults()
        defaults.set("not a url", forKey: AppConfiguration.Defaults.ollamaBaseURLKey)

        let configuration = AppConfiguration(defaults: defaults)

        expectEqual(configuration.ollamaBaseURL, AppConfiguration.Defaults.defaultOllamaBaseURL)
    }

    @Test
    func defaults_fallsBackForInvalidLMStudioBaseURL() {
        let defaults = makeDefaults()
        defaults.set("not a url", forKey: AppConfiguration.Defaults.lmStudioBaseURLKey)

        let configuration = AppConfiguration(defaults: defaults)

        expectEqual(configuration.lmStudioBaseURL, AppConfiguration.Defaults.defaultLMStudioBaseURL)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppConfigurationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
