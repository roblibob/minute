import XCTest
@testable import MinuteCore

final class TranscriptionBackendSelectionStoreTests: XCTestCase {
    func testDefaultBackendFallsBackToWhisper() {
        let suite = "minute-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = TranscriptionBackendSelectionStore(defaults: defaults, key: "backend")

        XCTAssertEqual(store.selectedBackend(), .whisper)
    }

    func testFluidAudioModelSelectionDefaultsToV3() {
        let suite = "minute-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = FluidAudioASRModelSelectionStore(defaults: defaults, key: "fluid-model")

        XCTAssertEqual(store.selectedModel().id, FluidAudioASRModelCatalog.defaultModelID)
    }
}
