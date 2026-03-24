import MinuteCore
import SwiftUI

struct ModelsSettingsSection: View {
    @ObservedObject var model: ModelsSettingsViewModel
    @AppStorage(AppDefaultsKey.screenContextEnabled)
    private var screenContextEnabled: Bool = AppConfiguration.Defaults.defaultScreenContextEnabled

    var body: some View {
        Group {
            transcriptionSection
            ollamaSection
            summarizationSection
            screenContextSection
        }
    }

    private var transcriptionSection: some View {
        Section("Transcription") {
            VStack(alignment: .leading, spacing: 12) {
                TranscriptionBackendPicker(
                    backends: model.transcriptionBackends,
                    selection: $model.selectedTranscriptionBackendID
                )

                Divider()

                if model.isFluidAudioSelected {
                    FluidAudioASRModelPicker(
                        models: model.fluidAudioModels,
                        selection: $model.selectedFluidAudioModelID
                    )

                    Divider()

                    VocabularyBoostingSection(model: model)
                } else {
                    TranscriptionModelPicker(
                        models: model.transcriptionModels,
                        selection: $model.selectedTranscriptionModelID
                    )

                    Divider()

                    TranscriptionLanguagePicker(
                        languages: model.transcriptionLanguages,
                        selection: $model.selectedTranscriptionLanguage
                    )
                }

                Divider()

                ModelDownloadStatusView(
                    title: "\(model.selectedTranscriptionBackendDisplayName) models",
                    detail: "Downloads the local transcription models required by the current transcription setup.",
                    status: model.transcriptionDownloadStatusState,
                    progress: model.activeDownloadProgress,
                    showsSpinner: model.isCheckingModels,
                    message: model.transcriptionDownloadMessage,
                    buttonTitle: downloadButtonTitle,
                    buttonEnabled: model.canStartModelDownload,
                    style: .plain,
                    action: { model.startDownload() }
                )
            }
        }
    }

    private var summarizationSection: some View {
        Section("Summarization") {
            VStack(alignment: .leading, spacing: 12) {
                SummarizationProviderPicker(
                    providers: model.inferenceProviders,
                    selection: $model.selectedSummarizationProviderID,
                    ollamaModelTag: $model.selectedSummarizationOllamaModelTag
                )

                if model.selectedSummarizationProviderID == InferenceProvider.ollama.rawValue {
                    InferenceCapabilityStatusView(
                        title: "Summarization validation",
                        state: model.summarizationAvailabilityState,
                        discoveredModelTags: model.ollamaDiscoveredModelTags,
                        isRefreshing: model.isRefreshingAvailability,
                        onRefresh: { model.refreshAvailability() }
                    )
                }

                if model.isBuiltInSummarizationProviderSelected {
                    Divider()

                    SummarizationModelPicker(
                        models: model.summarizationModels,
                        selection: $model.selectedSummarizationModelID
                    )

                    Divider()

                    ModelDownloadStatusView(
                        title: "Built-in summarization model",
                        detail: "Downloads the selected local summarization model when you use the built-in provider.",
                        status: model.summarizationDownloadStatusState,
                        progress: model.activeDownloadProgress,
                        showsSpinner: model.isCheckingModels,
                        message: model.summarizationDownloadMessage,
                        buttonTitle: downloadButtonTitle,
                        buttonEnabled: model.canStartModelDownload,
                        style: .plain,
                        action: { model.startDownload() }
                    )
                }

                Divider()

                SummarizationContextWindowPicker(
                    presets: model.summarizationContextWindowPresets,
                    recommendedPreset: model.recommendedSummarizationContextWindowPreset,
                    selection: $model.selectedSummarizationContextWindowPreset
                )
            }
        }
    }

    @ViewBuilder
    private var ollamaSection: some View {
        if model.showsOllamaEndpointConfiguration {
            Section("Ollama") {
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
        }
    }

    private var screenContextSection: some View {
        Section("Screen Context") {
            VStack(alignment: .leading, spacing: 12) {
                SettingsToggleRow(
                    "Enhance notes with selected screen context",
                    detail: "Choose a window each time you start recording. No video is stored.",
                    isOn: $screenContextEnabled
                )

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                VisionProviderPicker(
                    providers: model.inferenceProviders,
                    builtInModels: model.visionModels,
                    selection: $model.selectedVisionProviderID,
                    builtInModelSelection: $model.selectedVisionModelID,
                    ollamaModelTag: $model.selectedVisionOllamaModelTag
                )

                if model.selectedVisionProviderID == InferenceProvider.ollama.rawValue {
                    InferenceCapabilityStatusView(
                        title: "Screen context validation",
                        state: model.visionAvailabilityState,
                        discoveredModelTags: model.ollamaDiscoveredModelTags,
                        isRefreshing: model.isRefreshingAvailability,
                        onRefresh: { model.refreshAvailability() }
                    )
                }

                if model.isBuiltInVisionProviderSelected {
                    Divider()

                    ModelDownloadStatusView(
                        title: "Built-in screen context model",
                        detail: "Downloads the selected local screen-context model when you use the built-in provider.",
                        status: model.screenContextDownloadStatusState,
                        progress: model.activeDownloadProgress,
                        showsSpinner: model.isCheckingModels,
                        message: model.screenContextDownloadMessage,
                        buttonTitle: downloadButtonTitle,
                        buttonEnabled: model.canStartModelDownload,
                        style: .plain,
                        action: { model.startDownload() }
                    )
                }

                Divider()

                ScreenContextSettingsSection(title: nil, showsMasterToggle: false)
                }
                .disabled(!screenContextEnabled)
                .opacity(screenContextEnabled ? 1 : 0.55)
            }
        }
    }

    private var downloadButtonTitle: String {
        switch model.state {
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
}
