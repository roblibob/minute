import SwiftUI

struct SettingsView: View {
    @StateObject private var model = VaultSettingsModel()

    var body: some View {
        Form {
            Section("Vault") {
                HStack {
                    Text("Vault root")
                    Spacer()
                    Text(model.vaultRootPathDisplay)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Button("Choose vault…") {
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

            Section("Folders") {
                TextField("Meetings folder (relative)", text: $model.meetingsRelativePath)
                TextField("Audio folder (relative)", text: $model.audioRelativePath)
                TextField("Transcript folder (relative)", text: $model.transcriptsRelativePath)
                Text("Defaults: Meetings, Meetings/_audio, and Meetings/_transcripts")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 560, minHeight: 360)
    }
}

#Preview {
    SettingsView()
}
