import MinuteCore
import ScreenCaptureKit
import SwiftUI

struct ScreenContextWindowPickerPopover: View {
    let currentSelection: ScreenContextWindowSelection?
    let onSelect: (ScreenContextWindowSelection?) -> Void

    @State private var windows: [RecordingWindowItem] = []
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

    private let curatedBlacklistedBundleIdentifiers: Set<String> = [
        // Always exclude Minute itself (and any other app you want hidden).
        // Note: we also dynamically exclude Bundle.main.bundleIdentifier at runtime.
        "com.roblibob.Minute",
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

    private let curatedBlacklistedApplicationNames: Set<String> = [
        // Always exclude Minute itself (and any other app you want hidden).
        "Minute",
    ]

    private var effectiveBlacklistedBundleIdentifiers: Set<String> {
        var result = curatedBlacklistedBundleIdentifiers
        if let mainBundleIdentifier = Bundle.main.bundleIdentifier {
            result.insert(mainBundleIdentifier)
        }
        return result
    }

    private let minimumWindowSize = CGSize(width: 120, height: 80)

    private let curatedAppOrder: [String] = [
        "Microsoft Teams",
        "Slack",
        "Zoom",
        "Google Chrome",
        "Safari",
        "Arc",
        "Discord",
        "FaceTime"
    ]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Screen Context")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.minuteTextPrimary)
                Spacer()
                Button("Refresh") {
                    Task { await loadWindows() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isLoading)
            }

            pickerContent
        }
        .padding(12)
        .frame(width: 360, height: 340)
        .task { await loadWindows() }
    }

    @ViewBuilder
    private var pickerContent: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            Text(errorMessage)
                .minuteCaption()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            List {
                ScreenContextNoneRow(isSelected: currentSelection == nil)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(nil)
                    }

                SwiftUI.ForEach(windows, id: \.id) { window in
                    let selection = ScreenContextWindowSelection(
                        bundleIdentifier: window.bundleIdentifier ?? "",
                        applicationName: window.applicationName,
                        windowTitle: window.windowTitle
                    )

                    RecordingWindowRow(
                        title: window.windowTitle.isEmpty ? "Untitled Window" : window.windowTitle,
                        appName: window.applicationName,
                        isSelected: currentSelection == selection
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(selection)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @MainActor
    private func loadWindows() async {
        isLoading = true
        errorMessage = nil

        let permissionGranted = await ScreenRecordingPermission.refresh()
        guard permissionGranted else {
            windows = []
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
                let lhsKey = sortKey(appName: lhs.applicationName, title: lhs.windowTitle)
                let rhsKey = sortKey(appName: rhs.applicationName, title: rhs.windowTitle)
                if lhsKey != rhsKey {
                    return lhsKey < rhsKey
                }
                if lhs.applicationName != rhs.applicationName {
                    return lhs.applicationName < rhs.applicationName
                }
                return lhs.windowTitle < rhs.windowTitle
            }

            windows = items
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
        if let bundleIdentifier, effectiveBlacklistedBundleIdentifiers.contains(bundleIdentifier) {
            return false
        }
        if excludedApplicationNames.contains(applicationName) {
            return false
        }
        if curatedBlacklistedApplicationNames.contains(applicationName) {
            return false
        }
        if applicationName.localizedCaseInsensitiveCompare("Minute") == .orderedSame {
            return false
        }

        return true
    }

    private func sortKey(appName: String, title: String) -> Int {
        let normalizedApp = appName.lowercased()
        let normalizedTitle = title.lowercased()

        let basePriority = curatedAppOrder.firstIndex { normalizedApp.contains($0.lowercased()) }
            ?? curatedAppOrder.count

        if normalizedTitle.contains("meet") || normalizedTitle.contains("teams") || normalizedTitle.contains("zoom") {
            return min(basePriority, 1)
        }

        return basePriority
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

private struct RecordingWindowRow: View {
    let title: String
    let appName: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(appName)
                    .minuteCaption()
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        }
    }
}

private struct ScreenContextNoneRow: View {
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("None")
                    .font(.body)
                Text("Mute screen context")
                    .minuteCaption()
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        }
    }
}

private struct RecordingWindowItem: Identifiable {
    let id: CGWindowID
    let bundleIdentifier: String?
    let applicationName: String
    let windowTitle: String
}
