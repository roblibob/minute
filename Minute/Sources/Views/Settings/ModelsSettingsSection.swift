import MinuteCore
import SwiftUI

struct ModelsSettingsSection: View {
    @ObservedObject var model: ModelsSettingsViewModel
    @AppStorage(AppDefaultsKey.screenContextEnabled)
    private var screenContextEnabled: Bool = AppConfiguration.Defaults.defaultScreenContextEnabled

    var body: some View {
        Group {
            transcriptionSection
            summarizationSection
            screenContextSection
            localProvidersSection
            modelReadinessSection
        }
    }

    private var transcriptionSection: some View {
        Section("Transcription Setup") {
            VStack(alignment: .leading, spacing: 14) {
                TranscriptionBackendPicker(
                    backends: model.transcriptionBackends,
                    selection: $model.selectedTranscriptionBackendID
                )

                if model.isFluidAudioSelected {
                    FluidAudioASRModelPicker(
                        models: model.fluidAudioModels,
                        selection: $model.selectedFluidAudioModelID
                    )

                    VocabularyBoostingSection(model: model)
                } else {
                    TranscriptionModelPicker(
                        models: model.transcriptionModels,
                        selection: $model.selectedTranscriptionModelID
                    )

                    TranscriptionLanguagePicker(
                        languages: model.transcriptionLanguages,
                        selection: $model.selectedTranscriptionLanguage
                    )
                }
            }
        }
    }

    private var summarizationSection: some View {
        Section("Summarization Setup") {
            VStack(alignment: .leading, spacing: 14) {
                SummarizationProviderPicker(
                    providers: model.inferenceProviders,
                    selection: $model.selectedSummarizationProviderID,
                    ollamaModelTag: $model.selectedSummarizationOllamaModelTag,
                    lmStudioModelIdentifier: $model.selectedSummarizationLMStudioModelIdentifier
                )

                if model.selectedSummarizationProviderID == InferenceProvider.ollama.rawValue {
                    InferenceCapabilityStatusView(
                        title: "Summarization validation",
                        state: model.summarizationAvailabilityState,
                        discoveredModelReferences: model.ollamaDiscoveredModelTags,
                        discoveredModelsTitle: "Downloaded in Ollama",
                        isRefreshing: model.isRefreshingAvailability,
                        onRefresh: { model.refreshAvailability() }
                    )
                } else if model.selectedSummarizationProviderID == InferenceProvider.lmStudio.rawValue {
                    InferenceCapabilityStatusView(
                        title: "Summarization validation",
                        state: model.summarizationAvailabilityState,
                        discoveredModelReferences: model.lmStudioDiscoveredModelIdentifiers,
                        discoveredModelsTitle: "Available in LM Studio",
                        isRefreshing: model.isRefreshingAvailability,
                        onRefresh: { model.refreshAvailability() }
                    )
                }

                if model.isBuiltInSummarizationProviderSelected {
                    SummarizationModelPicker(
                        models: model.summarizationModels,
                        selection: $model.selectedSummarizationModelID
                    )
                }

                SummarizationContextWindowPicker(
                    presets: model.summarizationContextWindowPresets,
                    recommendedPreset: model.recommendedSummarizationContextWindowPreset,
                    selection: $model.selectedSummarizationContextWindowPreset
                )
            }
        }
    }

    private var screenContextSection: some View {
        Section("Screen Context Setup") {
            VStack(alignment: .leading, spacing: 14) {
                SettingsToggleRow(
                    "Enhance notes with selected screen context",
                    detail: "Choose a window each time you start recording. No video is stored.",
                    isOn: $screenContextEnabled
                )

                VStack(alignment: .leading, spacing: 12) {
                    VisionProviderPicker(
                        providers: model.inferenceProviders,
                        builtInModels: model.visionModels,
                        selection: $model.selectedVisionProviderID,
                        builtInModelSelection: $model.selectedVisionModelID,
                        ollamaModelTag: $model.selectedVisionOllamaModelTag,
                        lmStudioModelIdentifier: $model.selectedVisionLMStudioModelIdentifier
                    )

                    if model.selectedVisionProviderID == InferenceProvider.ollama.rawValue {
                        InferenceCapabilityStatusView(
                            title: "Screen context validation",
                            state: model.visionAvailabilityState,
                            discoveredModelReferences: model.ollamaDiscoveredModelTags,
                            discoveredModelsTitle: "Downloaded in Ollama",
                            isRefreshing: model.isRefreshingAvailability,
                            onRefresh: { model.refreshAvailability() }
                        )
                    } else if model.selectedVisionProviderID == InferenceProvider.lmStudio.rawValue {
                        InferenceCapabilityStatusView(
                            title: "Screen context validation",
                            state: model.visionAvailabilityState,
                            discoveredModelReferences: model.lmStudioDiscoveredModelIdentifiers,
                            discoveredModelsTitle: "Available in LM Studio",
                            isRefreshing: model.isRefreshingAvailability,
                            onRefresh: { model.refreshAvailability() }
                        )
                    }

                    ScreenContextSettingsSection(title: nil, showsMasterToggle: false)
                }
                .disabled(!screenContextEnabled)
                .opacity(screenContextEnabled ? 1 : 0.55)
            }
        }
    }

    @ViewBuilder
    private var localProvidersSection: some View {
        if model.showsOllamaEndpointConfiguration || model.showsLMStudioEndpointConfiguration {
            Section("Local Provider Connections") {
                VStack(alignment: .leading, spacing: 14) {
                    if model.showsOllamaEndpointConfiguration {
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

                    if model.showsLMStudioEndpointConfiguration {
                        SettingsFieldBlock(
                            title: "LM Studio base URL",
                            subtitle: "Use the full LM Studio endpoint, including protocol and port."
                        ) {
                            SettingsSingleLineInput(
                                text: $model.selectedLMStudioBaseURLString,
                                placeholder: AppConfiguration.Defaults.defaultLMStudioBaseURL
                            )
                        }
                    }
                }
            }
        }
    }

    private var modelReadinessSection: some View {
        Section("Model Readiness & Downloads") {
            VStack(alignment: .leading, spacing: 14) {
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

                if model.isBuiltInSummarizationProviderSelected {
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

                if model.isBuiltInVisionProviderSelected {
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
