import MinuteCore
import SwiftUI

struct ModelsSettingsSection: View {
    @ObservedObject var model: ModelsSettingsViewModel

    var body: some View {
        Section("Models") {
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

                    SettingsStatusIcon(isReady: isReady, showsAttention: showsRetry)
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
                        model.startDownload()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!buttonEnabled)

                    Spacer()
                }
            }
            .padding(.vertical, 6)
            .onAppear {
                model.refresh()
            }
        }
    }

    private var isReady: Bool {
        if case .ready = model.state {
            return true
        }
        return false
    }

    private var showsRetry: Bool {
        if case .needsDownload = model.state {
            return true
        }
        return false
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

private struct SettingsStatusIcon: View {
    let isReady: Bool
    let showsAttention: Bool

    var body: some View {
        let iconName: String
        let color: Color

        if isReady {
            iconName = "checkmark.circle.fill"
            color = .green
        } else if showsAttention {
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
