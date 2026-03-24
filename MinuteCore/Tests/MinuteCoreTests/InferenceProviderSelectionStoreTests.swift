import Foundation
import Testing
@testable import MinuteCore

struct InferenceProviderSelectionStoreTests {
    @Test
    func defaults_toBuiltInForAllCapabilities() {
        let defaults = makeDefaults()
        let store = InferenceProviderSelectionStore(defaults: defaults)

        #expect(store.selectedProvider(for: .summarization) == .builtIn)
        #expect(store.selectedProvider(for: .vision) == .builtIn)
        #expect(store.selectedOllamaModelTag(for: .summarization) == nil)
        #expect(store.selectedOllamaModelTag(for: .vision) == nil)
    }

    @Test
    func persistsProvidersIndependentlyByCapability() {
        let defaults = makeDefaults()
        let store = InferenceProviderSelectionStore(defaults: defaults)

        store.setSelectedProvider(.ollama, for: .summarization)
        store.setSelectedProvider(.builtIn, for: .vision)

        #expect(store.selectedProvider(for: .summarization) == .ollama)
        #expect(store.selectedProvider(for: .vision) == .builtIn)
    }

    @Test
    func persistsAndNormalizesOllamaTagsIndependently() {
        let defaults = makeDefaults()
        let store = InferenceProviderSelectionStore(defaults: defaults)

        store.setSelectedOllamaModelTag("  llama3.2  ", for: .summarization)
        store.setSelectedOllamaModelTag("llava", for: .vision)

        #expect(store.selectedOllamaModelTag(for: .summarization) == "llama3.2")
        #expect(store.selectedOllamaModelTag(for: .vision) == "llava")

        store.setSelectedOllamaModelTag("   ", for: .vision)
        #expect(store.selectedOllamaModelTag(for: .vision) == nil)
        #expect(store.selectedOllamaModelTag(for: .summarization) == "llama3.2")
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "InferenceProviderSelectionStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
