import AppKit
import SwiftUI

struct SettingsOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()

            MainSettingsView()
                .frame(width: 680, height: 480)
                .minutePanelStyle()
        }
        .transition(.opacity)
    }
}

#Preview {
    SettingsOverlayView()
        .environmentObject(AppNavigationModel())
}
