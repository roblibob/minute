//
//  MinuteApp.swift
//  Minute
//
//  Created by Robert Holst on 12/19/25.
//

import SwiftUI

@main
struct MinuteApp: App {
    @StateObject private var appState = AppNavigationModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
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
        }
    }
}
