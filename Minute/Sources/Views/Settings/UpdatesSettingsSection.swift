import SwiftUI

struct UpdatesSettingsSection: View {
    @ObservedObject var model: UpdaterViewModel

    var body: some View {
        if model.isUpdaterEnabled {
            Section("Updates") {
                SettingsToggleRow(
                    "Automatically check for updates",
                    detail: "Check for new Minute releases in the background.",
                    isOn: Binding(
                        get: { model.automaticallyChecksForUpdates },
                        set: { model.setAutomaticallyChecksForUpdates($0) }
                    )
                )

                SettingsToggleRow(
                    "Automatically download updates",
                    detail: "Download available updates before you choose to install them.",
                    isOn: Binding(
                        get: { model.automaticallyDownloadsUpdates },
                        set: { model.setAutomaticallyDownloadsUpdates($0) }
                    )
                )

                SettingsActionRow {
                    Button("Check for Updates...") {
                        model.checkForUpdates()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canCheckForUpdates)
                }
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
