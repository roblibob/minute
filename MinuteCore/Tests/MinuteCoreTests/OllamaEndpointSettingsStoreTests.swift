import Foundation
import Testing
@testable import MinuteCore

struct OllamaEndpointSettingsStoreTests {
    @Test
    func defaultsToLocalLoopbackEndpoint() {
        let defaults = makeDefaults()
        let store = OllamaEndpointSettingsStore(defaults: defaults)

        #expect(store.selectedBaseURLString() == AppConfiguration.Defaults.defaultOllamaBaseURL)
        #expect(store.selectedBaseURL() == URL(string: AppConfiguration.Defaults.defaultOllamaBaseURL))
    }

    @Test
    func persistsTrimmedCustomEndpoint() {
        let defaults = makeDefaults()
        let store = OllamaEndpointSettingsStore(defaults: defaults)

        store.setSelectedBaseURLString("  http://192.168.1.20:11434  ")

        #expect(store.selectedBaseURLString() == "http://192.168.1.20:11434")
        #expect(store.selectedBaseURL() == URL(string: "http://192.168.1.20:11434"))
    }

    @Test
    func emptyEndpointResetsToDefault() {
        let defaults = makeDefaults()
        let store = OllamaEndpointSettingsStore(defaults: defaults)

        store.setSelectedBaseURLString("http://192.168.1.20:11434")
        store.setSelectedBaseURLString("   ")

        #expect(store.selectedBaseURLString() == AppConfiguration.Defaults.defaultOllamaBaseURL)
        #expect(defaults.string(forKey: AppConfiguration.Defaults.ollamaBaseURLKey) == nil)
    }

    @Test
    func invalidEndpointFallsBackToDefault() {
        let defaults = makeDefaults()
        let store = OllamaEndpointSettingsStore(defaults: defaults)

        store.setSelectedBaseURLString("not a url")

        #expect(store.selectedBaseURLString() == AppConfiguration.Defaults.defaultOllamaBaseURL)
        #expect(defaults.string(forKey: AppConfiguration.Defaults.ollamaBaseURLKey) == nil)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "OllamaEndpointSettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
