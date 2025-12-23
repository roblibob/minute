import SwiftUI

struct GeneralSettingsSection: View {
    @AppStorage(AppDefaultsKey.saveAudio) private var saveAudio: Bool = true
    @AppStorage(AppDefaultsKey.saveTranscript) private var saveTranscript: Bool = true

    var body: some View {
        Section("Options") {
            Toggle("Save audio", isOn: $saveAudio)
                .toggleStyle(.switch)
                .tint(.accentColor)

            Text("When off, audio is not saved to the vault or linked in the note.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Save transcript", isOn: $saveTranscript)
                .toggleStyle(.switch)
                .tint(.accentColor)

            Text("When off, the transcript file and link are omitted from the note.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    Form {
        GeneralSettingsSection()
    }
    .frame(width: 420)
}
