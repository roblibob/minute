import AppKit
import Combine
import Foundation
import MinuteCore

@MainActor
final class MeetingNotesBrowserViewModel: ObservableObject {

    @Published private(set) var notes: [MeetingNoteItem] = []
    @Published private(set) var isRefreshing: Bool = false
    @Published private(set) var sidebarErrorMessage: String?

    @Published private(set) var isLoadingContent: Bool = false
    @Published private(set) var noteContent: String?
    @Published private(set) var overlayErrorMessage: String?
    @Published private(set) var renderPlainText: Bool = false
    @Published private(set) var selectedItem: MeetingNoteItem?
    @Published var isOverlayPresented: Bool = false

    private let browserProvider: @Sendable () -> any MeetingNotesBrowsing
    private var listTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var defaultsObserver: AnyCancellable?

    init(browserProvider: @escaping @Sendable () -> any MeetingNotesBrowsing = MeetingNotesBrowserViewModel.defaultBrowserProvider) {
        self.browserProvider = browserProvider

        defaultsObserver = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    deinit {
        listTask?.cancel()
        loadTask?.cancel()
    }

    func refresh() {
        listTask?.cancel()
        sidebarErrorMessage = nil
        isRefreshing = true

        let provider = browserProvider
        listTask = Task { [weak self] in
            do {
                let notes = try await provider().listNotes()
                await MainActor.run {
                    self?.notes = notes
                    self?.isRefreshing = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    self?.isRefreshing = false
                }
            } catch {
                let message = (error as? MinuteError)?.errorDescription ?? String(describing: error)
                await MainActor.run {
                    self?.notes = []
                    self?.sidebarErrorMessage = message
                    self?.isRefreshing = false
                }
            }
        }
    }

    func select(_ item: MeetingNoteItem) {
        loadTask?.cancel()
        selectedItem = item
        noteContent = nil
        overlayErrorMessage = nil
        renderPlainText = false
        isLoadingContent = true
        isOverlayPresented = true

        let provider = browserProvider
        loadTask = Task { [weak self] in
            do {
                let content = try await provider().loadNoteContent(for: item)
                let shouldRenderPlainText = Self.shouldRenderPlainText(content)

                await MainActor.run {
                    self?.noteContent = content
                    self?.renderPlainText = shouldRenderPlainText
                    self?.isLoadingContent = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    self?.isLoadingContent = false
                }
            } catch {
                let message = (error as? MinuteError)?.errorDescription ?? "Failed to load note."
                await MainActor.run {
                    self?.overlayErrorMessage = message
                    self?.isLoadingContent = false
                }
            }
        }
    }

    func retryLoadContent() {
        guard let item = selectedItem else { return }
        select(item)
    }

    func dismissOverlay() {
        loadTask?.cancel()
        isOverlayPresented = false
        selectedItem = nil
        noteContent = nil
        overlayErrorMessage = nil
        renderPlainText = false
        isLoadingContent = false
    }

    func openInObsidian() {
        guard let fileURL = selectedItem?.fileURL else { return }
        let path = fileURL.path
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+")
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: allowed),
              let obsidianURL = URL(string: "obsidian://open?path=\(encoded)") else {
            return
        }
        _ = NSWorkspace.shared.open(obsidianURL)
    }

    nonisolated private static func defaultBrowserProvider() -> any MeetingNotesBrowsing {
        let defaults = UserDefaults.standard
        let meetingsRelativePathKey = "meetingsRelativePath"
        let vaultRootBookmarkKey = "vaultRootBookmark"
        let meetingsRelativePath = defaults.string(forKey: meetingsRelativePathKey) ?? "Meetings"
        let bookmarkStore = UserDefaultsVaultBookmarkStore(key: vaultRootBookmarkKey)
        let access = VaultAccess(bookmarkStore: bookmarkStore)
        return VaultMeetingNotesBrowser(vaultAccess: access, meetingsRelativePath: meetingsRelativePath)
    }

    private static func shouldRenderPlainText(_ content: String) -> Bool {
        do {
            _ = try AttributedString(markdown: content)
            return false
        } catch {
            return true
        }
    }
}
