import Foundation
import Testing
@testable import MinuteCore

struct StagePreferencesStoreTests {
    @Test
    func load_defaultsWhenUnset() {
        let suite = "minute-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = StagePreferencesStore(
            defaults: defaults,
            meetingTypeKey: "meetingType",
            languageProcessingKey: "language",
            microphoneEnabledKey: "mic",
            systemAudioEnabledKey: "system"
        )

        let loaded = store.load()

        expectEqual(loaded, .default)
    }

    @Test
    func roundTrip_saveThenLoad() {
        let suite = "minute-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = StagePreferencesStore(
            defaults: defaults,
            meetingTypeKey: "meetingType",
            languageProcessingKey: "language",
            microphoneEnabledKey: "mic",
            systemAudioEnabledKey: "system"
        )

        let prefs = StagePreferences(
            meetingType: .planning,
            languageProcessing: .autoPreserve,
            microphoneEnabled: false,
            systemAudioEnabled: true
        )

        store.save(prefs)

        let loaded = store.load()
        expectEqual(loaded, prefs)
    }

    @Test
    func clear_removesKeysAndReturnsDefaults() {
        let suite = "minute-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = StagePreferencesStore(
            defaults: defaults,
            meetingTypeKey: "meetingType",
            languageProcessingKey: "language",
            microphoneEnabledKey: "mic",
            systemAudioEnabledKey: "system"
        )

        store.save(
            StagePreferences(
                meetingType: .designReview,
                languageProcessing: .autoPreserve,
                microphoneEnabled: false,
                systemAudioEnabled: false
            )
        )

        store.clear()

        let loaded = store.load()
        expectEqual(loaded, .default)
    }
}
