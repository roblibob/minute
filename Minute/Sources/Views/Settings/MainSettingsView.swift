import SwiftUI

struct MainSettingsView: View {
    @EnvironmentObject private var appState: AppNavigationModel
    @EnvironmentObject private var updaterViewModel: UpdaterViewModel
    @StateObject private var vaultModel = VaultSettingsModel()
    @StateObject private var modelsModel = ModelsSettingsViewModel()
    @StateObject private var meetingTypesModel = MeetingTypesSettingsViewModel()

    @AppStorage("minute.settings.lastCategoryID")
    private var lastCategoryIDRaw: String = SettingsCategoryDefinition.ID.general.rawValue

    @State private var selection: SettingsCategoryDefinition.ID?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .onAppear {
            selection = resolvedSelection(candidate: SettingsCategoryDefinition.ID(rawValue: lastCategoryIDRaw))
        }
        .onChange(of: selection) { _, newValue in
            guard let newValue else { return }
            lastCategoryIDRaw = newValue.rawValue
        }
        .onChange(of: availableCategories.map(\.id)) { _, _ in
            selection = resolvedSelection(candidate: selection)
        }
    }

    private var detail: some View {
        VStack(spacing: 8) {
            settingsHeader

            Group {
                if let currentSelection {
                    switch currentSelection {
                    case .general:
                        Form {
                            GeneralSettingsSection()
                        }
                    case .storage:
                        Form {
                            VaultConfigurationView(model: vaultModel, style: .settings)
                        }
                    case .speakers:
                        Form {
                            KnownSpeakersSettingsSection(mode: .manage)
                        }
                    case .privacy:
                        Form {
                            PermissionsSettingsSection()
                        }
                    case .ai:
                        Form {
                            ModelsSettingsSection(model: modelsModel)
                        }
                    case .meetingTypes:
                        Form {
                            MeetingTypesSettingsSection(model: meetingTypesModel)
                        }
                    case .updates:
                        Form {
                            UpdatesSettingsSection(model: updaterViewModel)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Settings unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text("No settings categories are currently available.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        List(availableCategories, selection: $selection) { category in
            Label(category.title, systemImage: category.iconName)
                .imageScale(.medium)
                .tag(category.id)
                .accessibilityLabel(category.accessibilityLabel)
        }
        .accessibilityLabel("Settings categories")
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .frame(width: 230)
    }

    private var settingsHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(currentCategoryDefinition?.title ?? "Settings")
                    .font(.title3.bold())

                Text(currentCategoryDefinition?.description ?? "Adjust app preferences and behavior.")
                    .minuteCaption()
            }

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

    private var availableCategories: [SettingsCategoryDefinition] {
        SettingsCategoryCatalog.categories(updatesEnabled: updaterViewModel.isUpdaterEnabled)
    }

    private var currentSelection: SettingsCategoryDefinition.ID? {
        resolvedSelection(candidate: selection)
    }

    private var currentCategoryDefinition: SettingsCategoryDefinition? {
        guard let currentSelection else { return nil }
        return availableCategories.first(where: { $0.id == currentSelection })
    }

    private func resolvedSelection(candidate: SettingsCategoryDefinition.ID?) -> SettingsCategoryDefinition.ID? {
        SettingsCategoryCatalog.fallbackSelection(current: candidate, available: availableCategories)
    }
}

#Preview {
    MainSettingsView()
        .environmentObject(AppNavigationModel())
        .environmentObject(UpdaterViewModel.preview)
        .frame(width: 900, height: 620)
}
