import Foundation
import Testing
@testable import Minute
@testable import MinuteCore

struct ModelsSettingsViewModelVocabularyBoostingTests {
    @Test
    func savesGlobalVocabularySettings_withNormalizedTerms() async throws {
        let suite = "ModelsSettingsViewModelVocabularyBoostingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let backendStore = TranscriptionBackendSelectionStore(defaults: defaults, key: "backend")
        backendStore.setSelectedBackendID(TranscriptionBackend.fluidAudio.rawValue)

        let vocabularyStore = VocabularyBoostingSettingsStore(
            defaults: defaults,
            enabledKey: "vb-enabled",
            termsKey: "vb-terms",
            strengthKey: "vb-strength",
            updatedAtKey: "vb-updated"
        )

        let model = await MainActor.run {
            ModelsSettingsViewModel(
                modelManager: StubModelManager(validation: ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])),
                summarizationModelStore: SummarizationModelSelectionStore(defaults: defaults, key: "sum"),
                transcriptionModelStore: TranscriptionModelSelectionStore(defaults: defaults, key: "trans"),
                transcriptionBackendStore: backendStore,
                fluidAudioModelStore: FluidAudioASRModelSelectionStore(defaults: defaults, key: "fluid"),
                vocabularySettingsStore: vocabularyStore
            )
        }

        await MainActor.run {
            model.vocabularyBoostingEnabled = true
            model.vocabularyBoostingStrength = .aggressive
            model.vocabularyBoostingTermsInput = "  Acme  \nACME, roadmap"
        }

        let stored = vocabularyStore.load()
        #expect(stored.enabled == true)
        #expect(stored.strength == VocabularyBoostingStrength.aggressive)
        #expect(stored.terms == ["Acme", "roadmap"])
    }

    @Test
    func showsVocabularyReadinessRow_whenCtcVocabularyModelMissing() async throws {
        let suite = "ModelsSettingsViewModelVocabularyReadinessTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let backendStore = TranscriptionBackendSelectionStore(defaults: defaults, key: "backend")
        backendStore.setSelectedBackendID(TranscriptionBackend.fluidAudio.rawValue)

        let model = await MainActor.run {
            ModelsSettingsViewModel(
                modelManager: StubModelManager(
                    validation: ModelValidationResult(
                        missingModelIDs: ["fluidaudio/asr-v3-ctc-vocab"],
                        invalidModelIDs: []
                    )
                ),
                summarizationModelStore: SummarizationModelSelectionStore(defaults: defaults, key: "sum"),
                transcriptionModelStore: TranscriptionModelSelectionStore(defaults: defaults, key: "trans"),
                transcriptionBackendStore: backendStore,
                fluidAudioModelStore: FluidAudioASRModelSelectionStore(defaults: defaults, key: "fluid")
            )
        }

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                model.showsVocabularyReadinessRow
            }
        }

        let message = await MainActor.run {
            model.vocabularyReadinessMessage
        }
        #expect(message?.contains("CTC") == true)
    }

    @Test
    func exposesUnsupportedMessage_whenFluidAudioBackendSelected() async throws {
        let suite = "ModelsSettingsViewModelVocabularyBoostingTests.unsupported.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let backendStore = TranscriptionBackendSelectionStore(defaults: defaults, key: "backend")
        backendStore.setSelectedBackendID(TranscriptionBackend.fluidAudio.rawValue)

        let model = await MainActor.run {
            ModelsSettingsViewModel(
                modelManager: StubModelManager(validation: ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])),
                summarizationModelStore: SummarizationModelSelectionStore(defaults: defaults, key: "sum"),
                transcriptionModelStore: TranscriptionModelSelectionStore(defaults: defaults, key: "trans"),
                transcriptionBackendStore: backendStore,
                fluidAudioModelStore: FluidAudioASRModelSelectionStore(defaults: defaults, key: "fluid")
            )
        }

        let message = await MainActor.run {
            model.vocabularyBoostingSupportMessage
        }

        #expect(message?.contains("currently unavailable") == true)
        #expect(message?.contains("FluidAudio") == true)
    }
}

private struct StubModelManager: ModelManaging {
    var validation: ModelValidationResult

    func ensureModelsPresent(progress: (@Sendable (ModelDownloadProgress) -> Void)?) async throws {
        _ = progress
    }

    func validateModels() async throws -> ModelValidationResult {
        validation
    }

    func removeModels(withIDs ids: [String]) async throws {
        _ = ids
    }
}
