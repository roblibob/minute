import AppKit
import AVFoundation
import CoreGraphics
@preconcurrency import ScreenCaptureKit
import SwiftUI

struct PermissionsSettingsSection: View {
    @State private var microphonePermissionGranted = false
    @State private var screenRecordingPermissionGranted = false

    var body: some View {
        Section("Permissions") {
            PermissionSettingsRow(
                title: "Microphone Access",
                detail: "Required to record your voice.",
                isGranted: microphonePermissionGranted,
                actionTitle: microphonePermissionGranted ? "Granted" : "Request Access",
                action: requestMicrophonePermission
            )

            PermissionSettingsRow(
                title: "Screen + System Audio Recording",
                detail: "Required to capture system audio.",
                isGranted: screenRecordingPermissionGranted,
                actionTitle: screenRecordingPermissionGranted ? "Granted" : "Request Access",
                action: requestScreenRecordingPermission
            )

            Text("You can also grant permissions in System Settings > Privacy & Security.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            refreshPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissions()
        }
    }

    private func refreshPermissions() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        microphonePermissionGranted = (status == .authorized)
        Task {
            let granted = await ScreenRecordingPermission.refresh()
            screenRecordingPermissionGranted = granted
        }
    }

    private func requestMicrophonePermission() {
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            microphonePermissionGranted = granted
        }
    }

    private func requestScreenRecordingPermission() {
        Task {
            let granted = await ScreenRecordingPermission.request()
            screenRecordingPermissionGranted = granted
        }
    }
}

private struct PermissionSettingsRow: View {
    let title: String
    let detail: String
    let isGranted: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            PermissionStatusIcon(isReady: isGranted)

            Button(actionTitle) {
                action()
            }
            .minuteStandardButtonStyle()
            .disabled(isGranted)
        }
        .padding(.vertical, 6)
    }
}

private struct PermissionStatusIcon: View {
    let isReady: Bool

    var body: some View {
        Image(systemName: isReady ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundStyle(isReady ? Color.green : Color.red)
            .font(.title3)
            .accessibilityLabel(isReady ? "Ready" : "Needs attention")
    }
}

@MainActor
enum ScreenRecordingPermission {
    static func refresh() async -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func request() async -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }

        let granted = CGRequestScreenCaptureAccess()
        if granted {
            return true
        }

        return await canAccessShareableContent()
    }

    private static func canAccessShareableContent() async -> Bool {
        await withCheckedContinuation { continuation in
            SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { content, error in
                if error != nil {
                    continuation.resume(returning: false)
                } else {
                    continuation.resume(returning: content != nil)
                }
            }
        }
    }
}
