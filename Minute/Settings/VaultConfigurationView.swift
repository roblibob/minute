import SwiftUI

struct VaultConfigurationView: View {
    enum Style {
        case settings
        case wizard
    }

    @ObservedObject var model: VaultSettingsModel
    let style: Style

    var body: some View {
        switch style {
        case .settings:
            Group {
                Section("Vault") {
                    vaultRootSection
                }

                Section("Folders") {
                    foldersSection
                }
            }

        case .wizard:
            VStack(alignment: .leading, spacing: 16) {
                Text("Vault")
                    .font(.title3.bold())
                vaultRootSection

                Divider()

                Text("Folders")
                    .font(.title3.bold())
                foldersSection
            }
        }
    }

    private var vaultRootSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Vault root")
                Spacer()
                Text(model.vaultRootPathDisplay)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Button("Choose vault...") {
                    Task { await model.chooseVaultRootFolder() }
                }

                Button("Clear") {
                    model.clearVaultSelection()
                }
                .disabled(model.vaultRootPathDisplay == "Not selected")

                Spacer()

                Button("Verify access") {
                    model.verifyAccessAndCreateFolders()
                }
            }

            if let message = model.lastVerificationMessage {
                Text(message)
                    .foregroundStyle(.green)
            }

            if let error = model.lastErrorMessage {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
    }

    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Meetings folder (relative)", text: $model.meetingsRelativePath)
            TextField("Audio folder (relative)", text: $model.audioRelativePath)
            TextField("Transcript folder (relative)", text: $model.transcriptsRelativePath)
            Text("Defaults: Meetings, Meetings/_audio, and Meetings/_transcripts")
                .foregroundStyle(.secondary)
        }
    }
}
