import AppKit
import CoreVideo
import MinuteCore
import ScreenCaptureKit
import SwiftUI

struct ScreenContextWindowPickerPopover: View {
    let currentSelection: ScreenContextWindowSelection?
    let onDismiss: () -> Void
    let onSelect: (ScreenContextWindowSelection?) -> Void

    @State private var windows: [RecordingWindowItem] = []
    @State private var captureWindowsByID: [CGWindowID: SCWindow] = [:]
    @State private var thumbnailImagesByWindowID: [CGWindowID: NSImage] = [:]
    @State private var appIconsByWindowID: [CGWindowID: NSImage] = [:]
    @State private var thumbnailRequestID: UUID = UUID()
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
        "Minute",
    ]

    private var effectiveBlacklistedBundleIdentifiers: Set<String> {
        var result = curatedBlacklistedBundleIdentifiers
        if let mainBundleIdentifier = Bundle.main.bundleIdentifier {
            result.insert(mainBundleIdentifier)
        }
        return result
    }

    private var normalizedExcludedBundleIdentifiers: Set<String> {
        Set(excludedBundleIdentifiers.map(normalizeToken))
    }

    private var normalizedEffectiveBlacklistedBundleIdentifiers: Set<String> {
        Set(effectiveBlacklistedBundleIdentifiers.map(normalizeToken))
    }

    private var normalizedExcludedApplicationNames: Set<String> {
        Set(excludedApplicationNames.map(normalizeApplicationName))
    }

    private var normalizedCuratedBlacklistedApplicationNames: Set<String> {
        Set(curatedBlacklistedApplicationNames.map(normalizeApplicationName))
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

    private let meetingBundleHints: [String] = [
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "us.zoom",
        "com.google.meet",
        "com.google.chrome",
        "com.apple.safari",
        "company.thebrowser.browser",
        "com.tinyspeck.slackmacgap",
        "com.webex.meetingsapp",
        "com.cisco.webexmeetingsapp",
        "com.discord",
        "com.apple.facetime"
    ]

    private let meetingAppNameHints: [String] = [
        "teams",
        "zoom",
        "meet",
        "webex",
        "slack",
        "discord",
        "facetime"
    ]

    private let meetingTitleHints: [String] = [
        "meeting",
        "standup",
        "daily",
        "workshop",
        "sync",
        "huddle",
        "call",
        "1:1",
        "one on one",
        "retro",
        "planning",
        "review",
        "grooming",
        "sprint",
        "town hall"
    ]

    private var suggestedWindows: [RecordingWindowItem] {
        var seenApplications = Set<String>()
        var suggestions: [RecordingWindowItem] = []

        for window in windows {
            let key = window.bundleIdentifier.lowercased()
            guard seenApplications.insert(key).inserted else { continue }
            suggestions.append(window)
            if suggestions.count == 3 {
                break
            }
        }

        return suggestions
    }

    private var remainingWindows: [RecordingWindowItem] {
        let suggestedIDs = Set(suggestedWindows.map(\.id))
        return windows.filter { !suggestedIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            pickerContent
        }
        .padding(16)
        .frame(width: 760, height: 430)
        .task { await loadWindows() }
        .onDisappear {
            thumbnailRequestID = UUID()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Suggested windows")
                .font(.system(size: 12, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(Color.minuteTextSecondary)

            Spacer()

            Button("Refresh") {
                Task { await loadWindows() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isLoading)

            Button("Disable") {
                onSelect(nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(currentSelection == nil)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.minuteTextSecondary)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(Color.minuteSurfaceStrong)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Close screen context window picker"))
        }
    }

    @ViewBuilder
    private var pickerContent: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text(errorMessage)
                    .minuteCaption()
                    .multilineTextAlignment(.center)

                Button("Retry") {
                    Task { await loadWindows() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if windows.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "display.slash")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.minuteTextMuted)
                Text("No shareable windows found.")
                    .minuteCaption()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        SwiftUI.ForEach(suggestedWindows, id: \.id) { window in
                            SuggestedWindowCard(
                                window: window,
                                thumbnail: thumbnailImagesByWindowID[window.id],
                                appIcon: appIconsByWindowID[window.id],
                                isSelected: currentSelection == selection(for: window),
                                action: {
                                    onSelect(selection(for: window))
                                }
                            )
                        }
                    }

                    if !remainingWindows.isEmpty {
                        Divider()

                        LazyVStack(spacing: 8) {
                            SwiftUI.ForEach(remainingWindows, id: \.id) { window in
                                RecordingWindowRow(
                                    title: window.windowTitle.isEmpty ? "Untitled Window" : window.windowTitle,
                                    appName: window.applicationName,
                                    appIcon: appIconsByWindowID[window.id],
                                    isSelected: currentSelection == selection(for: window)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSelect(selection(for: window))
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @MainActor
    private func loadWindows() async {
        isLoading = true
        errorMessage = nil
        windows = []
        captureWindowsByID = [:]
        thumbnailImagesByWindowID = [:]
        appIconsByWindowID = [:]
        thumbnailRequestID = UUID()

        let permissionGranted = await ScreenRecordingPermission.refresh()
        guard permissionGranted else {
            errorMessage = "Screen recording permission is required to list windows. Grant access in Settings."
            isLoading = false
            return
        }

        do {
            let content = try await fetchShareableContent()
            var items: [RecordingWindowItem] = []
            var resolvedWindows: [CGWindowID: SCWindow] = [:]

            for window in content.windows {
                guard let app = window.owningApplication else { continue }
                let bundleIdentifier = app.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !bundleIdentifier.isEmpty else { continue }
                let title = (window.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard shouldIncludeWindow(
                    bundleIdentifier: bundleIdentifier,
                    applicationName: app.applicationName,
                    title: title,
                    frame: window.frame
                ) else {
                    continue
                }

                let item = RecordingWindowItem(
                    id: window.windowID,
                    bundleIdentifier: bundleIdentifier,
                    applicationName: app.applicationName,
                    windowTitle: title,
                    processID: app.processID,
                    windowLayer: window.windowLayer,
                    isOnScreen: window.isOnScreen,
                    isActive: window.isActive,
                    frame: window.frame
                )
                items.append(item)
                resolvedWindows[window.windowID] = window
            }

            items.sort { lhs, rhs in
                let lhsScore = windowScore(lhs)
                let rhsScore = windowScore(rhs)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }

                let lhsRank = curatedAppRank(for: lhs.applicationName)
                let rhsRank = curatedAppRank(for: rhs.applicationName)
                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }

                if lhs.isActive != rhs.isActive {
                    return lhs.isActive && !rhs.isActive
                }

                if lhs.isOnScreen != rhs.isOnScreen {
                    return lhs.isOnScreen && !rhs.isOnScreen
                }

                return lhs.windowTitle < rhs.windowTitle
            }

            windows = items
            captureWindowsByID = resolvedWindows

            var icons: [CGWindowID: NSImage] = [:]
            for item in items {
                guard let icon = applicationIcon(bundleIdentifier: item.bundleIdentifier) else { continue }
                icons[item.id] = icon
            }
            appIconsByWindowID = icons

            isLoading = false
            await loadSuggestedWindowThumbnails()
        } catch {
            errorMessage = "Unable to load shareable windows."
            isLoading = false
        }
    }

    @MainActor
    private func loadSuggestedWindowThumbnails() async {
        let requestID = UUID()
        thumbnailRequestID = requestID
        thumbnailImagesByWindowID = [:]

        for item in suggestedWindows {
            guard thumbnailRequestID == requestID else { return }
            guard let window = captureWindowsByID[item.id] else { continue }
            guard let thumbnail = try? await captureWindowThumbnail(for: window) else { continue }
            guard thumbnailRequestID == requestID else { return }
            thumbnailImagesByWindowID[item.id] = thumbnail
        }
    }

    private func selection(for window: RecordingWindowItem) -> ScreenContextWindowSelection {
        ScreenContextWindowSelection(
            bundleIdentifier: window.bundleIdentifier,
            applicationName: window.applicationName,
            windowTitle: window.windowTitle
        )
    }

    private func applicationIcon(bundleIdentifier: String) -> NSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }

    private func shouldIncludeWindow(
        bundleIdentifier: String,
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

        if isExcludedBundleIdentifier(bundleIdentifier) {
            return false
        }
        if isCuratedBlacklistedBundleIdentifier(bundleIdentifier) {
            return false
        }
        let normalizedName = normalizeApplicationName(applicationName)
        if normalizedExcludedApplicationNames.contains(normalizedName) {
            return false
        }
        if isCuratedBlacklistedApplicationName(normalizedName) {
            return false
        }
        return true
    }

    private func isExcludedBundleIdentifier(_ bundleIdentifier: String) -> Bool {
        let normalized = normalizeToken(bundleIdentifier)
        return normalizedExcludedBundleIdentifiers.contains(normalized)
    }

    private func isCuratedBlacklistedBundleIdentifier(_ bundleIdentifier: String) -> Bool {
        let normalized = normalizeToken(bundleIdentifier)
        if normalizedEffectiveBlacklistedBundleIdentifiers.contains(normalized) {
            return true
        }

        return normalizedEffectiveBlacklistedBundleIdentifiers.contains { blacklist in
            normalized.hasPrefix(blacklist + ".")
        }
    }

    private func isCuratedBlacklistedApplicationName(_ normalizedApplicationName: String) -> Bool {
        guard !normalizedApplicationName.isEmpty else { return false }
        if normalizedCuratedBlacklistedApplicationNames.contains(normalizedApplicationName) {
            return true
        }

        let leadingToken = normalizedApplicationName
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .first
            .map(String.init) ?? ""

        guard !leadingToken.isEmpty else { return false }
        return normalizedCuratedBlacklistedApplicationNames.contains(leadingToken)
    }

    private func normalizeApplicationName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        if lowercased.hasSuffix(".app") {
            return String(lowercased.dropLast(4))
        }
        return lowercased
    }

    private func normalizeToken(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func windowScore(_ window: RecordingWindowItem) -> Int {
        let normalizedBundle = normalizeToken(window.bundleIdentifier)
        let normalizedAppName = normalizeApplicationName(window.applicationName)
        let normalizedTitle = normalizeApplicationName(window.windowTitle)

        var score = 0

        if meetingBundleHints.contains(where: { normalizedBundle.contains(normalizeToken($0)) }) {
            score += 60
        }

        if meetingAppNameHints.contains(where: { normalizedAppName.contains(normalizeToken($0)) }) {
            score += 42
        }

        let titleHintMatches = meetingTitleHints.reduce(into: 0) { count, hint in
            if normalizedTitle.contains(normalizeToken(hint)) {
                count += 1
            }
        }
        score += min(titleHintMatches, 3) * 16

        if window.isActive {
            score += 22
        }

        if window.isOnScreen {
            score += 10
        }

        if window.windowLayer == 0 {
            score += 8
        } else if window.windowLayer > 0 {
            score -= min(window.windowLayer, 20)
        }

        let area = max(window.frame.width * window.frame.height, 1)
        let areaBoost = min(Int(area / 120_000), 14)
        score += areaBoost

        let curatedRank = curatedAppRank(for: window.applicationName)
        if curatedRank < curatedAppOrder.count {
            score += max(0, (curatedAppOrder.count - curatedRank) * 2)
        }

        return score
    }

    private func curatedAppRank(for appName: String) -> Int {
        let normalizedApp = appName.lowercased()
        return curatedAppOrder.firstIndex { normalizedApp.contains($0.lowercased()) }
            ?? curatedAppOrder.count
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

    private func captureWindowThumbnail(for window: SCWindow) async throws -> NSImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = makeScreenshotConfiguration(for: filter)
        let image = try await captureImage(filter: filter, configuration: configuration)
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    private func captureImage(
        filter: SCContentFilter,
        configuration: SCStreamConfiguration
    ) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: MinuteError.screenCaptureUnavailable)
                }
            }
        }
    }

    private func makeScreenshotConfiguration(for filter: SCContentFilter) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = false
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = false
        configuration.scalesToFit = true

        let rect = filter.contentRect
        guard rect.width > 0, rect.height > 0 else {
            return configuration
        }

        let scale = CGFloat(filter.pointPixelScale)
        let sourceWidth = rect.width * scale
        let sourceHeight = rect.height * scale
        let maxDimension: CGFloat = 560
        let fitRatio = min(1.0, maxDimension / max(sourceWidth, sourceHeight))

        configuration.width = size_t(max(1, Int(sourceWidth * fitRatio)))
        configuration.height = size_t(max(1, Int(sourceHeight * fitRatio)))
        return configuration
    }
}

private struct SuggestedWindowCard: View {
    let window: RecordingWindowItem
    let thumbnail: NSImage?
    let appIcon: NSImage?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(placeholderGradient)

                    if let thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    }

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(thumbnail == nil ? 0.12 : 0.02))

                    HStack {
                        appBadge
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.minuteGlow)
                                .padding(8)
                        }
                    }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? Color.minuteGlow.opacity(0.9) : Color.minuteOutline, lineWidth: isSelected ? 2 : 1)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(window.windowTitle.isEmpty ? "Untitled Window" : window.windowTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.minuteTextPrimary)
                        .lineLimit(1)

                    Text(window.applicationName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.minuteTextSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var appBadge: some View {
        Group {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            } else {
                Text(String(window.applicationName.prefix(1)).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 28, height: 28)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.38))
        )
        .padding(8)
    }

    private var placeholderGradient: LinearGradient {
        let seed = abs(window.applicationName.hashValue % 360)
        let hue = Double(seed) / 360.0
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.50, brightness: 0.56),
                Color(hue: hue, saturation: 0.72, brightness: 0.44)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct RecordingWindowRow: View {
    let title: String
    let appName: String
    let appIcon: NSImage?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .padding(7)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.minuteSurfaceStrong)
                    )
            } else {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.minuteSurfaceStrong)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String(appName.prefix(1)).uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.minuteTextSecondary)
                    )
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.minuteTextPrimary)
                    .lineLimit(1)
                Text(appName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.minuteTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color.minuteGlow : Color.minuteTextMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

private struct RecordingWindowItem: Identifiable {
    let id: CGWindowID
    let bundleIdentifier: String
    let applicationName: String
    let windowTitle: String
    let processID: pid_t
    let windowLayer: Int
    let isOnScreen: Bool
    let isActive: Bool
    let frame: CGRect
}
