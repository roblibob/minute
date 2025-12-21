import Foundation

public struct VaultAccess {
    private let bookmarkStore: any VaultBookmarkStoring

    public init(bookmarkStore: some VaultBookmarkStoring) {
        self.bookmarkStore = bookmarkStore
    }

    public func resolveVaultRootURL() throws -> URL {
        guard let bookmark = bookmarkStore.loadVaultRootBookmark() else {
            throw MinuteError.vaultUnavailable
        }

        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            throw MinuteError.vaultUnavailable
        }

        return url
    }

    public func withVaultAccess<T>(_ work: (URL) throws -> T) throws -> T {
        let vaultRootURL = try resolveVaultRootURL()

        guard vaultRootURL.startAccessingSecurityScopedResource() else {
            throw MinuteError.vaultUnavailable
        }
        defer { vaultRootURL.stopAccessingSecurityScopedResource() }

        return try work(vaultRootURL)
    }

    public static func makeBookmarkData(forVaultRootURL url: URL) throws -> Data {
        try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
}
