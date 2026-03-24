import AppKit
import MinuteCore
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingHeader(stepTitle: stepTitle, stepSubtitle: stepSubtitle)

            GroupBox {
                stepContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }

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
        case .transcription:
            return "Transcription"
        case .summarization:
            return "Summarization"
        case .screenContext:
            return "Screen Context"
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
        case .transcription, .summarization, .screenContext:
            return model.modelStepDescription
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
        case .transcription:
            transcriptionSetupStep
        case .summarization:
            summarizationSetupStep
        case .screenContext:
            screenContextSetupStep
        case .vault:
            OnboardingVaultStep(model: model)
        case .complete:
            completionStep
        }
    }

    private var introStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("We will guide you through permissions, model downloads, and choosing your vault.")
                .foregroundStyle(.secondary)
        }
    }

    private var completionStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Permissions, models, and vault setup are ready.", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            Text("Minute is configured and ready to process meetings.")
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

    private var transcriptionSetupStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            TranscriptionBackendPicker(
                backends: model.transcriptionBackends,
                selection: $model.selectedTranscriptionBackendID
            )

            if model.isFluidAudioSelected {
                FluidAudioASRModelPicker(
                    models: model.fluidAudioModels,
                    selection: $model.selectedFluidAudioModelID
                )
            } else {
                TranscriptionModelPicker(
                    models: model.transcriptionModels,
                    selection: $model.selectedTranscriptionModelID
                )
            }

            ModelDownloadStatusView(
                title: "\(model.selectedTranscriptionBackendDisplayName) models",
                detail: "Download the local transcription model for the backend you selected.",
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

    private var summarizationSetupStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingProviderChoicePicker(
                title: "Summarization provider",
                selection: $model.selectedSummarizationProviderID
            )

            if model.showsOllamaEndpointConfigurationForSummarization {
                SettingsFieldBlock(
                    title: "Ollama base URL",
                    subtitle: "Use the full Ollama endpoint, including protocol and port."
                ) {
                    SettingsSingleLineInput(
                        text: $model.selectedOllamaBaseURLString,
                        placeholder: AppConfiguration.Defaults.defaultOllamaBaseURL
                    )
                }
            }

            if model.usesOllamaForSummarization {
                SettingsFieldBlock(
                    title: "Ollama model tag",
                    subtitle: "Use a summarization model that is already available in your Ollama daemon."
                ) {
                    SettingsSingleLineInput(
                        text: $model.selectedSummarizationOllamaModelTag,
                        placeholder: "e.g. llama3.2:latest"
                    )
                }

                InferenceCapabilityStatusView(
                    title: "Summarization validation",
                    state: model.summarizationAvailabilityState,
                    discoveredModelTags: model.ollamaDiscoveredModelTags,
                    isRefreshing: model.isRefreshingAvailability,
                    onRefresh: { model.refreshAvailability() }
                )
            } else {
                SummarizationModelPicker(
                    models: model.summarizationModels,
                    selection: $model.selectedSummarizationModelID
                )

                ModelDownloadStatusView(
                    title: "Built-in summarization model",
                    detail: "Download the local summarization model for the built-in provider.",
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

            SummarizationContextWindowPicker(
                presets: model.summarizationContextWindowPresets,
                recommendedPreset: model.recommendedSummarizationContextWindowPreset,
                selection: $model.selectedSummarizationContextWindowPreset
            )
        }
    }

    private var screenContextSetupStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsToggleRow(
                "Use screen context while summarizing",
                detail: "Minute will ask you to choose a window when you record. No video is stored.",
                isOn: $model.screenContextEnabled
            )

            if model.screenContextEnabled {
                OnboardingProviderChoicePicker(
                    title: "Screen context provider",
                    selection: $model.selectedVisionProviderID
                )

                if model.showsOllamaEndpointConfigurationForScreenContext {
                    SettingsFieldBlock(
                        title: "Ollama base URL",
                        subtitle: "Use the full Ollama endpoint, including protocol and port."
                    ) {
                        SettingsSingleLineInput(
                            text: $model.selectedOllamaBaseURLString,
                            placeholder: AppConfiguration.Defaults.defaultOllamaBaseURL
                        )
                    }
                }

                if model.usesOllamaForScreenContext {
                    SettingsFieldBlock(
                        title: "Ollama model tag",
                        subtitle: "Use an installed Ollama model that supports vision or screen-context input."
                    ) {
                        SettingsSingleLineInput(
                            text: $model.selectedVisionOllamaModelTag,
                            placeholder: "e.g. llava:latest"
                        )
                    }

                    InferenceCapabilityStatusView(
                        title: "Screen context validation",
                        state: model.visionAvailabilityState,
                        discoveredModelTags: model.ollamaDiscoveredModelTags,
                        isRefreshing: model.isRefreshingAvailability,
                        onRefresh: { model.refreshAvailability() }
                    )
                } else {
                    SummarizationModelPicker(
                        title: "Screen context model",
                        models: model.visionModels,
                        selection: $model.selectedVisionModelID
                    )

                    ModelDownloadStatusView(
                        title: "Built-in screen context model",
                        detail: "Download the local screen-context model for the built-in provider.",
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
            } else {
                Text("Screen context stays off by default. You can enable it later in Settings.")
                    .minuteCaption()
            }
        }
    }

}

private struct OnboardingHeader: View {
    let stepTitle: String
    let stepSubtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(stepTitle)
                    .font(.title2.bold())
                if let stepSubtitle {
                    Text(stepSubtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct OnboardingProviderChoicePicker: View {
    let title: String
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .minuteRowTitle()

            HStack(spacing: 12) {
                optionButton(
                    title: "Built-in",
                    subtitle: "Easy",
                    provider: .builtIn
                )
                optionButton(
                    title: "Ollama",
                    subtitle: "Advanced",
                    provider: .ollama
                )
            }
        }
    }

    private func optionButton(
        title: String,
        subtitle: String,
        provider: InferenceProvider
    ) -> some View {
        let isSelected = selection == provider.rawValue

        return Button {
            selection = provider.rawValue
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.accent)
                    }
                }

                Text(subtitle)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(provider.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.7) : Color.secondary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Spacer()
                Button(primaryTitle) {
                    onPrimary()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
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
        PermissionStatusRow(
            title: title,
            detail: detail,
            isGranted: isGranted,
            actionTitle: "Allow",
            iconSize: .title2,
            action: action
        )
        .frame(maxWidth: .infinity, alignment: .leading)
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
