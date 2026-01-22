import MinuteCore
import SwiftUI

struct GeneralSettingsSection: View {
    @AppStorage(AppDefaultsKey.saveAudio) private var saveAudio: Bool = AppConfiguration.Defaults.defaultSaveAudio
    @AppStorage(AppDefaultsKey.saveTranscript) private var saveTranscript: Bool = AppConfiguration.Defaults.defaultSaveTranscript

    var body: some View {
        Section("Options") {
            SettingsToggleRow(
                "Save audio",
                detail: "When off, audio is not saved to the vault or linked in the note.",
                isOn: $saveAudio
            )

            SettingsToggleRow(
                "Save transcript",
                detail: "When off, the transcript file and link are omitted from the note.",
                isOn: $saveTranscript
            )
        }
    }
}

#Preview {
    Form {
        GeneralSettingsSection()
    }
    .frame(width: 420)
}
