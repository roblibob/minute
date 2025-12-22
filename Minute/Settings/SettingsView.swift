import SwiftUI

struct SettingsView: View {
    @StateObject private var appState = AppNavigationModel()

    var body: some View {
        MainSettingsView()
            .environmentObject(appState)
            .frame(width: 680, height: 480)
    }
}

#Preview {
    SettingsView()
}
