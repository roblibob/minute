//
//  MinuteApp.swift
//  Minute
//
//  Created by Robert Holst on 12/19/25.
//

import AppKit
import Sparkle
import SwiftUI
import UserNotifications

@main
struct MinuteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppNavigationModel()
    @StateObject private var updaterViewModel: UpdaterViewModel
    private let updaterController: SPUStandardUpdaterController

    init() {
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController = controller
        _updaterViewModel = StateObject(wrappedValue: UpdaterViewModel(updater: controller.updater))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(updaterViewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    appState.showSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(model: updaterViewModel)
            }
        }
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        removeTopLevelMenuItems(titles: ["Edit", "View"])
        configureNotifications()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func removeTopLevelMenuItems(titles: [String]) {
        guard let mainMenu = NSApp.mainMenu else { return }
        for title in titles {
            if let item = mainMenu.items.first(where: { $0.title == title }) {
                mainMenu.removeItem(item)
            }
        }
    }

    private func configureNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let startAction = UNNotificationAction(
            identifier: MicActivityNotification.startActionIdentifier,
            title: "Start Recording",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: MicActivityNotification.categoryIdentifier,
            actions: [startAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.content.categoryIdentifier == MicActivityNotification.categoryIdentifier {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard response.notification.request.content.categoryIdentifier == MicActivityNotification.categoryIdentifier else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .minuteMicActivityShowPipeline, object: nil)

        if response.actionIdentifier == MicActivityNotification.startActionIdentifier {
            NotificationCenter.default.post(name: .minuteMicActivityStartRecording, object: nil)
        }
    }
}
