import SwiftUI

struct UpdatesSettingsSection: View {
    @ObservedObject var model: UpdaterViewModel

    var body: some View {
        if model.isUpdaterEnabled {
            Section("Updates") {
                Toggle(
                    "Automatically check for updates",
                    isOn: Binding(
                        get: { model.automaticallyChecksForUpdates },
                        set: { model.setAutomaticallyChecksForUpdates($0) }
                    )
                )
                Toggle(
                    "Automatically download updates",
                    isOn: Binding(
                        get: { model.automaticallyDownloadsUpdates },
                        set: { model.setAutomaticallyDownloadsUpdates($0) }
                    )
                )
                Button("Check for Updates...") {
                    model.checkForUpdates()
                }
                .disabled(!model.canCheckForUpdates)
            }
        }
    }
}

#Preview {
    Form {
        UpdatesSettingsSection(model: UpdaterViewModel.preview)
    }
    .padding()
    .frame(width: 520)
}
