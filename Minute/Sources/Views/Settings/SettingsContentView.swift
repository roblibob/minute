import SwiftUI

struct SettingsContentView: View {
    @ObservedObject var model: VaultSettingsModel

    var body: some View {
        Form {
            PermissionsSettingsSection()
            VaultConfigurationView(model: model, style: .settings)
        }
    }
}
