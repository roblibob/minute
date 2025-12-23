import AppKit
import SwiftUI

struct SettingsOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()

            MainSettingsView()
                .frame(width: 680, height: 480)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(NSColor.windowBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                )
        }
        .transition(.opacity)
    }
}

#Preview {
    SettingsOverlayView()
        .environmentObject(AppNavigationModel())
}
