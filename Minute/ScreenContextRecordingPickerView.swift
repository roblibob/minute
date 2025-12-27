import MinuteCore
import ScreenCaptureKit
import SwiftUI

struct ScreenContextRecordingPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (ScreenContextWindowSelection) -> Void

    @State private var windows: [RecordingWindowItem] = []
    @State private var selectedID: CGWindowID? = nil
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let excludedBundleIdentifiers: Set<String> = [
        "com.apple.WindowServer",
        "com.apple.SystemUIServer",
        "com.apple.dock",
        "com.apple.notificationcenterui",
        "com.apple.controlcenter",
        "com.apple.Spotlight",
        "com.apple.loginwindow",
        "com.apple.CoreServicesUIServer",
        "com.apple.ScreenCapture",
    ]

    private let excludedApplicationNames: Set<String> = [
        "Window Server",
        "SystemUIServer",
        "Dock",
        "Notification Center",
        "Control Center",
        "Spotlight",
        "loginwindow",
    ]

    private let minimumWindowSize = CGSize(width: 120, height: 80)

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Select Window")
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
                    SwiftUI.ForEach($windows, id: \.id) { window in
                        let windowValue = window.wrappedValue
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(windowValue.windowTitle.isEmpty ? "Untitled Window" : windowValue.windowTitle)
                                    .font(.body)
                                Text(windowValue.applicationName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedID == windowValue.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedID = windowValue.id
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Start Recording") {
                    guard let selection = selectedWindowSelection() else { return }
                    onSelect(selection)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedID == nil || isLoading)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 460)
        .task {
            await loadWindows()
        }
    }

    @MainActor
    private func loadWindows() async {
        isLoading = true
        errorMessage = nil

        let permissionGranted = await ScreenRecordingPermission.refresh()
        guard permissionGranted else {
            windows = []
            selectedID = nil
            errorMessage = "Screen recording permission is required to list windows. Grant access in Settings."
            isLoading = false
            return
        }

        do {
            let content = try await fetchShareableContent()
            let items: [RecordingWindowItem] = content.windows.compactMap { window -> RecordingWindowItem? in
                guard let app = window.owningApplication else { return nil }
                let title = (window.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard shouldIncludeWindow(
                    bundleIdentifier: app.bundleIdentifier,
                    applicationName: app.applicationName,
                    title: title,
                    frame: window.frame
                ) else { return nil }
                return RecordingWindowItem(
                    id: window.windowID,
                    bundleIdentifier: app.bundleIdentifier,
                    applicationName: app.applicationName,
                    windowTitle: title,
                )
            }
            .sorted { lhs, rhs in
                if lhs.applicationName == rhs.applicationName {
                    return lhs.windowTitle < rhs.windowTitle
                }
                return lhs.applicationName < rhs.applicationName
            }

            windows = items
            if let current = selectedID, !items.contains(where: { $0.id == current }) {
                selectedID = nil
            }
        } catch {
            errorMessage = "Unable to load shareable windows."
        }

        isLoading = false
    }

    private func shouldIncludeWindow(
        bundleIdentifier: String?,
        applicationName: String,
        title: String,
        frame: CGRect
    ) -> Bool {
        guard !title.isEmpty else { return false }
        guard frame.width >= minimumWindowSize.width,
              frame.height >= minimumWindowSize.height
        else {
            return false
        }

        if let bundleIdentifier, excludedBundleIdentifiers.contains(bundleIdentifier) {
            return false
        }
        if excludedApplicationNames.contains(applicationName) {
            return false
        }

        return true
    }

    private func selectedWindowSelection() -> ScreenContextWindowSelection? {
        guard let selectedID else { return nil }
        guard let window = windows.first(where: { $0.id == selectedID }) else { return nil }
        return ScreenContextWindowSelection(
            bundleIdentifier: window.bundleIdentifier,
            applicationName: window.applicationName,
            windowTitle: window.windowTitle
        )
    }

    private func fetchShareableContent() async throws -> SCShareableContent {
        try await withCheckedThrowingContinuation { continuation in
            SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: false) { content, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let content {
                    continuation.resume(returning: content)
                } else {
                    continuation.resume(throwing: MinuteError.screenCaptureUnavailable)
                }
            }
        }
    }
}

private struct RecordingWindowItem: Identifiable {
    let id: CGWindowID
    let bundleIdentifier: String
    let applicationName: String
    let windowTitle: String
}
