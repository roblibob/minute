import Foundation

public final class UserDefaultsVaultBookmarkStore: VaultBookmarkStoring {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "vaultRootBookmark") {
        self.defaults = defaults
        self.key = key
    }

    public func loadVaultRootBookmark() -> Data? {
        defaults.data(forKey: key)
    }

    public func saveVaultRootBookmark(_ bookmark: Data) {
        defaults.set(bookmark, forKey: key)
    }

    public func clearVaultRootBookmark() {
        defaults.removeObject(forKey: key)
    }
}
