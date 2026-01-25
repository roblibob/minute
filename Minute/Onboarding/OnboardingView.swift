import AppKit
import MinuteCore
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingHeader(stepTitle: stepTitle, stepSubtitle: stepSubtitle)

            stepContent

            Spacer(minLength: 0)

            OnboardingFooter(
                showsSkip: model.currentStep == .permissions && !model.permissionsReady,
                primaryTitle: model.primaryButtonTitle,
                primaryEnabled: model.primaryButtonEnabled,
                onSkip: { model.skipPermissions() },
                onPrimary: { model.advance() }
            )
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            model.refreshAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshAll()
        }
    }

    private var stepTitle: String {
        switch model.currentStep {
        case .intro:
            return "Welcome"
        case .permissions:
            return "Permissions"
        case .models:
            return "Models"
        case .vault:
            return "Vault Setup"
        case .complete:
            return "Ready"
        }
    }

    private var stepSubtitle: String? {
        switch model.currentStep {
        case .intro:
            return "Minute records meetings, transcribes them locally, and writes structured notes to your vault."
        case .permissions:
            return "Enable the required permissions to capture microphone and system audio."
        case .models:
            return "Download the local models used for transcription and summarization."
        case .vault:
            return "Choose where meeting notes and audio should be written."
        case .complete:
            return nil
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch model.currentStep {
        case .intro:
            introStep
        case .permissions:
            permissionsStep
        case .models:
            modelsStep
        case .vault:
            OnboardingVaultStep(model: model)
        case .complete:
            introStep
        }
    }

    private var introStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("We will guide you through permissions, model downloads, and choosing your vault.")
                .foregroundStyle(.secondary)
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            PermissionButtonRow(
                title: "Microphone Access",
                detail: "Required to record your voice.",
                isGranted: model.microphonePermissionGranted,
                action: { model.requestMicrophonePermission() }
            )

            PermissionButtonRow(
                title: "Screen + System Audio Recording",
                detail: "Required to capture system audio.",
                isGranted: model.screenRecordingPermissionGranted,
                action: { model.requestScreenRecordingPermission() }
            )

            Text("macOS may require a restart for screen recording permission to apply.")
                .minuteCaption()

            Text("You can skip this step and enable permissions later in Settings.")
                .minuteCaption()
        }
    }

    private var modelsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            TranscriptionModelPicker(
                models: model.transcriptionModels,
                selection: $model.selectedTranscriptionModelID
            )

            SummarizationModelPicker(
                models: model.summarizationModels,
                selection: $model.selectedSummarizationModelID
            )

            ModelDownloadStatusView(
                title: "Whisper + Llama models",
                detail: "Required for local transcription and summarization.",
                status: modelStatus,
                progress: modelProgressValue,
                showsSpinner: modelShowsSpinner,
                message: modelMessageText,
                buttonTitle: modelButtonTitle,
                buttonEnabled: modelButtonEnabled,
                style: .card,
                action: { model.startModelDownload() }
            )
        }
    }

}

private struct OnboardingHeader: View {
    let stepTitle: String
    let stepSubtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Minute")
                .font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text(stepTitle)
                    .font(.title2.bold())
                if let stepSubtitle {
                    Text(stepSubtitle)
                        .minuteRowSubtitle()
                }
            }
        }
    }
}

private struct OnboardingFooter: View {
    let showsSkip: Bool
    let primaryTitle: String
    let primaryEnabled: Bool
    let onSkip: () -> Void
    let onPrimary: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Divider()

            HStack {
                if showsSkip {
                    Button("Skip for now") {
                        onSkip()
                    }
                    .minuteStandardButtonStyle()
                }

                Spacer()
                Button(primaryTitle) {
                    onPrimary()
                }
                .minuteStandardButtonStyle()
                .disabled(!primaryEnabled)
            }
        }
    }
}

private struct OnboardingVaultStep: View {
    @ObservedObject var model: OnboardingViewModel
    @StateObject private var vaultModel = VaultSettingsModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Vault status")
                    .minuteRowTitle()
                Spacer()
                StatusIcon(isReady: model.vaultConfigured, size: .title3)
            }

            VaultConfigurationView(model: vaultModel, style: .wizard)
        }
    }
}

private struct PermissionButtonRow: View {
    let title: String
    let detail: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PermissionStatusRow(
                title: title,
                detail: detail,
                isGranted: isGranted,
                iconSize: .title2
            )
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .minuteCardStyle(padding: 12)
        }
        .buttonStyle(.plain)
    }
}

private extension OnboardingView {
    var modelStatus: StatusIcon.State {
        if case .ready = model.modelsState {
            return .ready
        }
        if case .needsDownload = model.modelsState {
            return .attention
        }
        return .blocked
    }

    var modelShowsSpinner: Bool {
        if case .checking = model.modelsState {
            return true
        }
        return false
    }

    var modelProgressValue: ModelDownloadProgress? {
        if case .downloading(let progress) = model.modelsState {
            return progress
        }
        return nil
    }

    var modelMessageText: String? {
        if case .needsDownload(let message) = model.modelsState {
            return message
        }
        return nil
    }

    var modelButtonTitle: String {
        switch model.modelsState {
        case .ready:
            return "Models Ready"
        case .downloading:
            return "Downloading..."
        case .needsDownload:
            return "Download Models"
        case .checking:
            return "Checking..."
        }
    }

    var modelButtonEnabled: Bool {
        switch model.modelsState {
        case .ready, .downloading, .checking:
            return false
        case .needsDownload:
            return true
        }
    }
}
