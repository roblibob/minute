import Sparkle
import SwiftUI

struct CheckForUpdatesView: View {
    @ObservedObject private var updaterViewModel: UpdaterViewModel

    init(updater: SPUUpdater) {
        self.updaterViewModel = UpdaterViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates...", action: updaterViewModel.checkForUpdates)
            .disabled(!updaterViewModel.canCheckForUpdates)
    }
}
