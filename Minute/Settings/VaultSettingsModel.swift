import AppKit
import Combine
import Foundation
import MinuteCore

@MainActor
final class VaultSettingsModel: ObservableObject {
    private enum DefaultsKey {
        static let vaultRootBookmark = "vaultRootBookmark"
        static let meetingsRelativePath = "meetingsRelativePath"
        static let audioRelativePath = "audioRelativePath"
        static let transcriptsRelativePath = "transcriptsRelativePath"
    }

    @Published var vaultRootPathDisplay: String = "Not selected"
    @Published var meetingsRelativePath: String {
        didSet { UserDefaults.standard.set(meetingsRelativePath, forKey: DefaultsKey.meetingsRelativePath) }
    }

    @Published var audioRelativePath: String {
        didSet { UserDefaults.standard.set(audioRelativePath, forKey: DefaultsKey.audioRelativePath) }
    }

    @Published var transcriptsRelativePath: String {
        didSet { UserDefaults.standard.set(transcriptsRelativePath, forKey: DefaultsKey.transcriptsRelativePath) }
    }

    @Published var lastVerificationMessage: String?
    @Published var lastErrorMessage: String?

    private let bookmarkStore = UserDefaultsVaultBookmarkStore(key: DefaultsKey.vaultRootBookmark)

    init() {
        let defaults = UserDefaults.standard
        self.meetingsRelativePath = defaults.string(forKey: DefaultsKey.meetingsRelativePath) ?? "Meetings"
        self.audioRelativePath = defaults.string(forKey: DefaultsKey.audioRelativePath) ?? "Meetings/_audio"
        self.transcriptsRelativePath = defaults.string(forKey: DefaultsKey.transcriptsRelativePath) ?? "Meetings/_transcripts"

        refreshVaultPathDisplay()
    }

    func chooseVaultRootFolder() async {
        lastErrorMessage = nil
        lastVerificationMessage = nil

        guard let url = await openFolderPanel() else {
            return
        }

        do {
            let bookmark = try VaultAccess.makeBookmarkData(forVaultRootURL: url)
            bookmarkStore.saveVaultRootBookmark(bookmark)
            refreshVaultPathDisplay()
        } catch {
            lastErrorMessage = "Failed to save vault bookmark: \(error.localizedDescription)"
        }
    }

    func clearVaultSelection() {
        bookmarkStore.clearVaultRootBookmark()
        refreshVaultPathDisplay()
    }

    func verifyAccessAndCreateFolders() {
        lastErrorMessage = nil
        lastVerificationMessage = nil

        let access = VaultAccess(bookmarkStore: bookmarkStore)

        do {
            try access.withVaultAccess { vaultRootURL in
                let location = VaultLocation(
                    vaultRootURL: vaultRootURL,
                    meetingsRelativePath: meetingsRelativePath,
                    audioRelativePath: audioRelativePath,
                    transcriptsRelativePath: transcriptsRelativePath
                )

                try FileManager.default.createDirectory(at: location.meetingsFolderURL, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: location.audioFolderURL, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: location.transcriptsFolderURL, withIntermediateDirectories: true)
            }

            lastVerificationMessage = "Vault access OK. Folders are ready."
        } catch let minuteError as MinuteError {
            lastErrorMessage = minuteError.errorDescription ?? minuteError.debugSummary
        } catch {
            lastErrorMessage = error.localizedDescription
        }

        refreshVaultPathDisplay()
    }

    private func refreshVaultPathDisplay() {
        let access = VaultAccess(bookmarkStore: bookmarkStore)
        do {
            let url = try access.resolveVaultRootURL()
            vaultRootPathDisplay = url.path
        } catch {
            vaultRootPathDisplay = "Not selected"
        }
    }

    private func openFolderPanel() async -> URL? {
        await withCheckedContinuation { continuation in
            let panel = NSOpenPanel()
            panel.title = "Select your Obsidian vault root folder"
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = false

            panel.begin { response in
                guard response == .OK, let url = panel.url else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: url)
            }
        }
    }
}
