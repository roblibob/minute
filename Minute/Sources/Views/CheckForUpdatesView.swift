import SwiftUI

struct CheckForUpdatesView: View {
    @ObservedObject var model: UpdaterViewModel

    var body: some View {
        Group {
            if model.isUpdaterEnabled {
                Button("Check for Updates...", action: model.checkForUpdates)
                    .disabled(!model.canCheckForUpdates)
            }
        }
    }
}
