import MinuteCore
import ScreenCaptureKit
import SwiftUI

struct ScreenContextSettingsSection: View {
    @AppStorage(AppDefaultsKey.screenContextEnabled) private var screenContextEnabled: Bool = false
    @AppStorage(AppDefaultsKey.screenContextVideoImportEnabled) private var videoImportEnabled: Bool = false

    var body: some View {
        Section("Screen Context") {
            Toggle("Enhance notes with selected screen content", isOn: $screenContextEnabled)
                .toggleStyle(.switch)
                .tint(.accentColor)

            Text("Choose a window each time you start recording. No video is stored.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Enhance video imports with frame text", isOn: $videoImportEnabled)
                .toggleStyle(.switch)
                .tint(.accentColor)

            Text("When enabled, video imports are sampled for on-screen text.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    Form {
        ScreenContextSettingsSection()
    }
    .frame(width: 480)
}
