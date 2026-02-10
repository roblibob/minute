import Foundation
import Testing
@testable import MinuteCore

struct StagePreferencesStoreMigrationTests {
    @Test
    func load_whenNoKeysExist_returnsDefaults() {
        let suite = "minute-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = StagePreferencesStore(defaults: defaults)

        let loaded = store.load()

        expectEqual(loaded, .default)
    }
}
