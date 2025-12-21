import Foundation

public protocol VaultBookmarkStoring {
    func loadVaultRootBookmark() -> Data?
    func saveVaultRootBookmark(_ bookmark: Data)
    func clearVaultRootBookmark()
}
