import AppKit
import MinuteCore
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Minute")
                .font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text(stepTitle)
                    .font(.title2.bold())
                if let subtitle = stepSubtitle {
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                }
            }

            stepContent

            Spacer(minLength: 0)

            Divider()

            HStack {
                if model.currentStep == .permissions && !model.permissionsReady {
                    Button("Skip for now") {
                        model.skipPermissions()
                    }
                    .minuteStandardButtonStyle()
                }

                Spacer()
                Button(model.primaryButtonTitle) {
                    model.advance()
                }
                .minuteStandardButtonStyle()
                .disabled(!model.primaryButtonEnabled)
            }
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
            PermissionRow(
                title: "Microphone Access",
                detail: "Required to record your voice.",
                isGranted: model.microphonePermissionGranted,
                action: { model.requestMicrophonePermission() }
            )

            PermissionRow(
                title: "Screen + System Audio Recording",
                detail: "Required to capture system audio.",
                isGranted: model.screenRecordingPermissionGranted,
                action: { model.requestScreenRecordingPermission() }
            )

            Text("macOS may require a restart for screen recording permission to apply.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("You can skip this step and enable permissions later in Settings.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var modelsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            SummarizationModelPicker(
                models: model.summarizationModels,
                selection: $model.selectedSummarizationModelID
            )

            ModelsRow(state: model.modelsState) {
                model.startModelDownload()
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
                    .font(.headline)
                Spacer()
                StatusIcon(isReady: model.vaultConfigured, retry: false)
            }

            VaultConfigurationView(model: vaultModel, style: .wizard)
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatusIcon(isReady: isGranted, retry: false)
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.tertiary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ModelsRow: View {
    let state: OnboardingViewModel.ModelsState
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Whisper + Llama models")
                        .font(.headline)
                    Text("Required for local transcription and summarization.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatusIcon(isReady: isReady, retry: showsRetry)
            }

            if let progress = progressValue {
                ProgressView(value: progress.fractionCompleted) {
                    Text(progress.label)
                }
            } else if showsSpinner {
                ProgressView("Checking models...")
            }

            if let message = messageText {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button(buttonTitle) {
                    action()
                }
                .minuteStandardButtonStyle()
                .disabled(!buttonEnabled)

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.tertiary, lineWidth: 1)
        )
    }

    private var isReady: Bool {
        if case .ready = state {
            return true
        }
        return false
    }

    private var showsRetry: Bool {
        if case .needsDownload = state {
            return true
        }
        return false
    }

    private var showsSpinner: Bool {
        if case .checking = state {
            return true
        }
        return false
    }

    private var progressValue: ModelDownloadProgress? {
        if case .downloading(let progress) = state {
            return progress
        }
        return nil
    }

    private var messageText: String? {
        if case .needsDownload(let message) = state {
            return message
        }
        return nil
    }

    private var buttonTitle: String {
        switch state {
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

    private var buttonEnabled: Bool {
        switch state {
        case .ready, .downloading, .checking:
            return false
        case .needsDownload:
            return true
        }
    }
}

private struct StatusIcon: View {
    let isReady: Bool
    let retry: Bool

    var body: some View {
        let iconName: String
        let color: Color

        if isReady {
            iconName = "checkmark.circle.fill"
            color = .green
        } else if retry {
            iconName = "arrow.clockwise.circle.fill"
            color = .orange
        } else {
            iconName = "xmark.circle.fill"
            color = .red
        }

        return Image(systemName: iconName)
            .foregroundStyle(color)
            .font(.title2)
            .accessibilityLabel(isReady ? "Ready" : "Needs attention")
    }
}
