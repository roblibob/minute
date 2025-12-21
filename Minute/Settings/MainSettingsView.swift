import SwiftUI

struct MainSettingsView: View {
    @EnvironmentObject private var appState: AppNavigationModel
    @StateObject private var model = VaultSettingsModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button("Back") {
                    appState.showPipeline()
                }
                .buttonStyle(.bordered)

                Spacer()

                Text("Settings")
                    .font(.largeTitle.bold())
            }

            SettingsContentView(model: model)

            Spacer(minLength: 0)
        }
        .padding(24)
    }
}

#Preview {
    MainSettingsView()
        .environmentObject(AppNavigationModel())
}
