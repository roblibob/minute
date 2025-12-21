import SwiftUI

struct SettingsContentView: View {
    @ObservedObject var model: VaultSettingsModel

    var body: some View {
        Form {
            VaultConfigurationView(model: model, style: .settings)
        }
    }
}
