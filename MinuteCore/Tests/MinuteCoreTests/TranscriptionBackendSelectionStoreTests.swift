import Testing
import Foundation
@testable import MinuteCore

struct TranscriptionBackendSelectionStoreTests {
    @Test
    func defaultBackendFallsBackToWhisper() {
        let suite = "minute-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = TranscriptionBackendSelectionStore(defaults: defaults, key: "backend")

        expectEqual(store.selectedBackend(), .whisper)
    }

    @Test
    func fluidAudioModelSelectionDefaultsToV3() {
        let suite = "minute-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = FluidAudioASRModelSelectionStore(defaults: defaults, key: "fluid-model")

        expectEqual(store.selectedModel().id, FluidAudioASRModelCatalog.defaultModelID)
    }
}
