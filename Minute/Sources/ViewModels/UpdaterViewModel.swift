import Combine
import Sparkle

final class UpdaterViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    @Published var automaticallyChecksForUpdates = true
    @Published var automaticallyDownloadsUpdates = false

    private let updater: SPUUpdater
    init(updater: SPUUpdater) {
        self.updater = updater

        let defaults = UserDefaults.standard
        if defaults.object(forKey: "SUAutomaticallyChecksForUpdates") == nil {
            updater.automaticallyChecksForUpdates = true
        }

        updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)

        updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$automaticallyChecksForUpdates)

        updater.publisher(for: \.automaticallyDownloadsUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$automaticallyDownloadsUpdates)
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }

    func setAutomaticallyChecksForUpdates(_ value: Bool) {
        updater.automaticallyChecksForUpdates = value
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
    }

    func setAutomaticallyDownloadsUpdates(_ value: Bool) {
        updater.automaticallyDownloadsUpdates = value
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
    }

    static var preview: UpdaterViewModel {
        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        return UpdaterViewModel(updater: controller.updater)
    }
}
