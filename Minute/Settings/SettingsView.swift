import SwiftUI

struct SettingsView: View {
    @StateObject private var appState = AppNavigationModel()
    @StateObject private var updaterViewModel = UpdaterViewModel.preview

    var body: some View {
        MainSettingsView()
            .environmentObject(appState)
            .environmentObject(updaterViewModel)
            .frame(width: 680, height: 480)
    }
}

#Preview {
    SettingsView()
}
