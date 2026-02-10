//
//  ContentView.swift
//  Minute
//
//  Created by Robert Holst on 12/19/25.
//

import MinuteCore
import SwiftUI


struct ContentView: View {
    @EnvironmentObject private var appState: AppNavigationModel
    @StateObject private var onboardingModel = OnboardingViewModel()

    var body: some View {
        Group {
            contentBody
        }
        .frame(minWidth: 1024, minHeight: 800)
        .background(MinuteTheme.windowBackground)
        .onAppear {
            onboardingModel.refreshAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: .minuteMicActivityShowPipeline)) { _ in
            appState.showPipeline()
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        if onboardingModel.isComplete {
            ZStack {
                PipelineContentView()

                if appState.mainContent == .settings {
                    SettingsOverlayView()
                }
            }
        } else {
            OnboardingView(model: onboardingModel)
        }
    }
}
#Preview(traits: .fixedLayout(width: 1024, height: 800)) {
    PipelineContentView()
        .environmentObject(AppNavigationModel())
}
