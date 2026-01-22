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
            PermissionStatusRow(
                title: "Microphone Access",
                detail: "Required to record your voice.",
                isGranted: microphonePermissionGranted,
                actionTitle: microphonePermissionGranted ? "Granted" : "Request Access",
                action: requestMicrophonePermission
            )

            PermissionStatusRow(
                title: "Screen + System Audio Recording",
                detail: "Required to capture system audio.",
                isGranted: screenRecordingPermissionGranted,
                actionTitle: screenRecordingPermissionGranted ? "Granted" : "Request Access",
                action: requestScreenRecordingPermission
            )

            Text("You can also grant permissions in System Settings > Privacy & Security.")
                .minuteFootnote()
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
