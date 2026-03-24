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
    @State private var forcesOnboardingForCurrentLaunch = ContentView.shouldForceOnboardingInDebugBuild()

    var body: some View {
        Group {
            contentBody
        }
        .frame(minWidth: 1024, minHeight: 800)
        .background(MinuteTheme.windowBackground)
        .onAppear {
            onboardingModel.refreshAll()
            if forcesOnboardingForCurrentLaunch {
                onboardingModel.startDebugWalkthrough()
            }
        }
        .onChange(of: onboardingModel.isComplete) { _, isComplete in
            if isComplete {
                forcesOnboardingForCurrentLaunch = false
            }
        }
        .onChange(of: onboardingModel.isDebugWalkthroughActive) { _, isActive in
            if !isActive {
                forcesOnboardingForCurrentLaunch = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .minuteMicActivityShowPipeline)) { _ in
            appState.showPipeline()
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        if showsMainApplication {
            ZStack {
                PipelineContentView()
                    .opacity(appState.mainContent == .pipeline ? 1 : 0)
                    .allowsHitTesting(appState.mainContent == .pipeline)
                    .accessibilityHidden(appState.mainContent != .pipeline)

                MainSettingsView()
                    .opacity(appState.mainContent == .settings ? 1 : 0)
                    .allowsHitTesting(appState.mainContent == .settings)
                    .accessibilityHidden(appState.mainContent != .settings)
            }
            .animation(.easeInOut(duration: 0.15), value: appState.mainContent)
        } else {
            OnboardingView(model: onboardingModel)
        }
    }

    private var showsMainApplication: Bool {
        onboardingModel.isComplete && !forcesOnboardingForCurrentLaunch
    }
}

extension ContentView {
    static let forceOnboardingEnvironmentKey = "MINUTE_FORCE_ONBOARDING"

    static func shouldForceOnboardingInDebugBuild(processInfo: ProcessInfo = .processInfo) -> Bool {
#if DEBUG
        let rawValue = processInfo.environment[forceOnboardingEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return rawValue == "1" || rawValue == "true" || rawValue == "yes"
#else
        _ = processInfo
        return false
#endif
    }
}

#Preview(traits: .fixedLayout(width: 1024, height: 800)) {
    ContentView()
        .environmentObject(AppNavigationModel())
        .environmentObject(UpdaterViewModel.preview)
}
