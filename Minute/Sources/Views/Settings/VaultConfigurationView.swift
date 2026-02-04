import MinuteCore
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
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Clear") {
                    model.clearVaultSelection()
                }
                .disabled(model.vaultRootPathDisplay == "Not selected")
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()
            }
        }
    }

    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Meetings folder (relative)", text: $model.meetingsRelativePath)
                .minuteTextFieldStyle()
            TextField("Audio folder (relative)", text: $model.audioRelativePath)
                .minuteTextFieldStyle()
            TextField("Transcript folder (relative)", text: $model.transcriptsRelativePath)
                .minuteTextFieldStyle()
            Text(
                "Defaults: \(AppConfiguration.Defaults.defaultMeetingsRelativePath), " +
                "\(AppConfiguration.Defaults.defaultAudioRelativePath), and " +
                "\(AppConfiguration.Defaults.defaultTranscriptsRelativePath)"
            )
                .minuteCaption()
        }
    }
}
