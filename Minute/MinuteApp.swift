//
//  MinuteApp.swift
//  Minute
//
//  Created by Robert Holst on 12/19/25.
//

import Sparkle
import SwiftUI

@main
struct MinuteApp: App {
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
