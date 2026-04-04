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
                Section("Vault Location") {
                    vaultRootSection
                }

                Section("Vault Folder Mapping") {
                    foldersSection
                }
            }

        case .wizard:
            VStack(alignment: .leading, spacing: 16) {
                Text("Vault")
                    .minuteSectionTitle()
                vaultRootSection

                Divider()

                Text("Folders")
                    .minuteSectionTitle()
                foldersSection
            }
        }
    }

    private var vaultRootSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsFieldBlock(
                title: "Vault root",
                subtitle: "Minute writes meeting notes, transcripts, and audio inside this vault."
            ) {
                SettingsReadOnlyValue(
                    text: model.vaultRootPathDisplay == "Not selected" ? "" : model.vaultRootPathDisplay,
                    placeholder: "Not selected"
                )
            }

            SettingsActionRow {
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
            }
        }
    }

    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsFieldBlock(
                title: "Meetings folder",
                subtitle: "Relative path for rendered meeting notes."
            ) {
                SettingsSingleLineInput(
                    text: $model.meetingsRelativePath,
                    placeholder: AppConfiguration.Defaults.defaultMeetingsRelativePath
                )
            }

            SettingsFieldBlock(
                title: "Audio folder",
                subtitle: "Relative path for saved WAV files."
            ) {
                SettingsSingleLineInput(
                    text: $model.audioRelativePath,
                    placeholder: AppConfiguration.Defaults.defaultAudioRelativePath
                )
            }

            SettingsFieldBlock(
                title: "Transcript folder",
                subtitle: "Relative path for rendered transcript Markdown files."
            ) {
                SettingsSingleLineInput(
                    text: $model.transcriptsRelativePath,
                    placeholder: AppConfiguration.Defaults.defaultTranscriptsRelativePath
                )
            }

            SettingsInlineMessage(
                text: "Defaults: \(AppConfiguration.Defaults.defaultMeetingsRelativePath), " +
                    "\(AppConfiguration.Defaults.defaultAudioRelativePath), and " +
                    "\(AppConfiguration.Defaults.defaultTranscriptsRelativePath)."
            )
        }
    }
}
