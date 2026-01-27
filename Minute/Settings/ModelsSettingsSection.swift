import MinuteCore
import SwiftUI

struct ModelsSettingsSection: View {
    @ObservedObject var model: ModelsSettingsViewModel

    var body: some View {
        Section("Models") {
            VStack(alignment: .leading, spacing: 12) {
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

                SummarizationModelPicker(
                    models: model.summarizationModels,
                    selection: $model.selectedSummarizationModelID
                )

                ModelDownloadStatusView(
                    title: "\(model.selectedTranscriptionBackendDisplayName) + Llama models",
                    detail: "Required for local transcription and summarization.",
                    status: statusState,
                    progress: progressValue,
                    showsSpinner: showsSpinner,
                    message: messageText,
                    buttonTitle: buttonTitle,
                    buttonEnabled: buttonEnabled,
                    style: .plain,
                    action: { model.startDownload() }
                )
            }
            .onAppear {
                model.refresh()
            }
        }
    }

    private var statusState: StatusIcon.State {
        if case .ready = model.state {
            return .ready
        }
        if case .needsDownload = model.state {
            return .attention
        }
        return .blocked
    }

    private var showsSpinner: Bool {
        if case .checking = model.state {
            return true
        }
        return false
    }

    private var progressValue: ModelDownloadProgress? {
        if case .downloading(let progress) = model.state {
            return progress
        }
        return nil
    }

    private var messageText: String? {
        if case .needsDownload(let message) = model.state {
            return message
        }
        return nil
    }

    private var buttonTitle: String {
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

    private var buttonEnabled: Bool {
        switch model.state {
        case .ready, .downloading, .checking:
            return false
        case .needsDownload:
            return true
        }
    }
}
