import MinuteCore
import ScreenCaptureKit
import SwiftUI

struct ScreenContextSettingsSection: View {
    @AppStorage(AppDefaultsKey.screenContextEnabled) private var screenContextEnabled: Bool = false
    @AppStorage(AppDefaultsKey.screenContextVideoImportEnabled) private var videoImportEnabled: Bool = false
    @State private var isPickerPresented = false
    @State private var selectionCount = 0

    private let store = ScreenContextSettingsStore()

    var body: some View {
        Section("Screen Context") {
            Toggle("Enhance notes with selected screen content", isOn: $screenContextEnabled)
                .toggleStyle(.switch)
                .tint(.accentColor)

            Text("Only text extracted from selected windows is used. No video is stored.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Select windows...") {
                isPickerPresented = true
            }
            .disabled(!screenContextEnabled)

            if selectionCount > 0 {
                Text("\(selectionCount) window(s) selected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No windows selected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Enhance video imports with frame text", isOn: $videoImportEnabled)
                .toggleStyle(.switch)
                .tint(.accentColor)

            Text("When enabled, video imports are sampled for on-screen text.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            selectionCount = store.selectedWindows().count
        }
        .onChange(of: isPickerPresented) { _, isPresented in
            if !isPresented {
                selectionCount = store.selectedWindows().count
            }
        }
        .sheet(isPresented: $isPickerPresented) {
            ScreenContextWindowPickerView(store: store)
        }
    }
}

private struct ScreenContextWindowPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let store: ScreenContextSettingsStore

    @State private var windows: [ScreenContextWindowItem] = []
    @State private var selectedIDs: Set<CGWindowID> = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Select Windows")
                    .font(.title3.bold())
                Spacer()
                Button("Refresh") {
                    Task { await loadWindows() }
                }
                .disabled(isLoading)
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List {
                    ForEach(windows) { window in
                        Toggle(isOn: binding(for: window)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(window.windowTitle)
                                    .font(.body)
                                Text(window.applicationName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    persistSelection()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isLoading)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 420)
        .task {
            await loadWindows()
        }
    }

    private func binding(for window: ScreenContextWindowItem) -> Binding<Bool> {
        Binding(
            get: { selectedIDs.contains(window.id) },
            set: { isSelected in
                if isSelected {
                    selectedIDs.insert(window.id)
                } else {
                    selectedIDs.remove(window.id)
                }
            }
        )
    }

    @MainActor
    private func loadWindows() async {
        isLoading = true
        errorMessage = nil

        do {
            let content = try await fetchShareableContent()
            let bundleID = Bundle.main.bundleIdentifier
            let selections = store.selectedWindows()

            let items: [ScreenContextWindowItem] = content.windows.compactMap { window in
                guard let app = window.owningApplication else { return nil }
                let appBundleID = app.bundleIdentifier
                guard let title = window.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                if let bundleID, appBundleID == bundleID { return nil }
                return ScreenContextWindowItem(
                    id: window.windowID,
                    bundleIdentifier: appBundleID,
                    applicationName: app.applicationName,
                    windowTitle: title
                )
            }
            .sorted { lhs, rhs in
                if lhs.applicationName == rhs.applicationName {
                    return lhs.windowTitle < rhs.windowTitle
                }
                return lhs.applicationName < rhs.applicationName
            }

            windows = items
            selectedIDs = Set(items.filter { item in
                selections.contains { selection in
                    selection.bundleIdentifier == item.bundleIdentifier &&
                    selection.windowTitle.caseInsensitiveCompare(item.windowTitle) == .orderedSame
                }
            }.map(\.id))
        } catch {
            errorMessage = "Unable to load shareable windows."
        }

        isLoading = false
    }

    private func persistSelection() {
        let selections = windows.filter { selectedIDs.contains($0.id) }.map { window in
            ScreenContextWindowSelection(
                bundleIdentifier: window.bundleIdentifier,
                applicationName: window.applicationName,
                windowTitle: window.windowTitle
            )
        }
        store.setSelectedWindows(selections)
    }

    private func fetchShareableContent() async throws -> SCShareableContent {
        try await withCheckedThrowingContinuation { continuation in
            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let content {
                    continuation.resume(returning: content)
                } else {
                    continuation.resume(throwing: MinuteError.audioExportFailed)
                }
            }
        }
    }
}

private struct ScreenContextWindowItem: Identifiable {
    let id: CGWindowID
    let bundleIdentifier: String
    let applicationName: String
    let windowTitle: String
}

#Preview {
    Form {
        ScreenContextSettingsSection()
    }
    .frame(width: 480)
}
