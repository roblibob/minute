import SwiftUI

struct MainSettingsView: View {
    @EnvironmentObject private var appState: AppNavigationModel
    @EnvironmentObject private var updaterViewModel: UpdaterViewModel
    @StateObject private var vaultModel = VaultSettingsModel()
    @StateObject private var modelsModel = ModelsSettingsViewModel()
    @State private var selection: SettingsSection? = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
    }

    private var detail: some View {
        VStack(spacing: 8) {
            settingsHeader

            Group {
                switch currentSelection {
                case .general:
                    Form {
                        GeneralSettingsSection()
                        ScreenContextSettingsSection()
                        VaultConfigurationView(model: vaultModel, style: .settings)
                    }
                case .permissions:
                    Form {
                        PermissionsSettingsSection()
                    }
                case .ai:
                    Form {
                        ModelsSettingsSection(model: modelsModel)
                    }
                case .updates:
                    Form {
                        UpdatesSettingsSection(model: updaterViewModel)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var sidebar: some View {
        List(SettingsSection.allCases, selection: $selection) { section in
            Label(section.title, systemImage: section.iconName)
                .imageScale(.medium)
                .tag(section)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .frame(width: 200)
    }

    private var settingsHeader: some View {
        HStack {
            Text(currentSelection.title)
                .font(.title3.bold())

            Spacer()

            Button {
                appState.showPipeline()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.minuteTextSecondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Settings")
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var currentSelection: SettingsSection {
        selection ?? .general
    }
}

private enum SettingsSection: CaseIterable, Identifiable {
    case general
    case permissions
    case ai
    case updates

    var id: Self { self }

    var title: String {
        switch self {
        case .general:
            return "General"
        case .permissions:
            return "Permissions"
        case .ai:
            return "AI"
        case .updates:
            return "Updates"
        }
    }

    var iconName: String {
        switch self {
        case .general:
            return "gearshape"
        case .permissions:
            return "hand.raised"
        case .ai:
            return "sparkles"
        case .updates:
            return "arrow.down.circle"
        }
    }
}

#Preview {
    MainSettingsView()
        .environmentObject(AppNavigationModel())
        .environmentObject(UpdaterViewModel.preview)
        .frame(width: 680, height: 480)
}
