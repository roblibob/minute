import SwiftUI

struct CheckForUpdatesView: View {
    @ObservedObject var model: UpdaterViewModel

    var body: some View {
        Button("Check for Updates...", action: model.checkForUpdates)
            .disabled(!model.canCheckForUpdates)
    }
}
