import SwiftUI

struct SettingsView: View {
    @StateObject private var model = VaultSettingsModel()

    var body: some View {
        SettingsContentView(model: model)
            .padding()
            .frame(minWidth: 560, minHeight: 360)
    }
}

#Preview {
    SettingsView()
}
