import AppKit
import SwiftUI

struct MainSettingsView: View {
    @EnvironmentObject private var appState: AppNavigationModel
    @StateObject private var vaultModel = VaultSettingsModel()
    @StateObject private var modelsModel = ModelsSettingsViewModel()
    @State private var selection: SettingsSection = .general

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                sidebar
                Divider()
                detail
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
    }

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.title2.bold())

            Spacer()

            Button {
                appState.showPipeline()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Settings")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: section.iconName)
                            .frame(width: 18)
                        Text(section.title)
                        Spacer()
                    }
                    .foregroundStyle(.primary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selection == section ? Color.accentColor.opacity(0.16) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(12)
        .frame(width: 180)
        .background(backgroundColor)
    }

    private var detail: some View {
        Group {
            switch selection {
            case .general:
                Form {
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
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(backgroundColor)
    }

    private var backgroundColor: Color {
        Color(NSColor.windowBackgroundColor)
    }
}

private enum SettingsSection: CaseIterable, Identifiable {
    case general
    case permissions
    case ai

    var id: Self { self }

    var title: String {
        switch self {
        case .general:
            return "General"
        case .permissions:
            return "Permissions"
        case .ai:
            return "AI"
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
        }
    }
}

#Preview {
    MainSettingsView()
        .environmentObject(AppNavigationModel())
        .frame(width: 680, height: 480)
}
