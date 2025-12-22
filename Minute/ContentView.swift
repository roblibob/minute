//
//  ContentView.swift
//  Minute
//
//  Created by Robert Holst on 12/19/25.
//

import MinuteCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var appState: AppNavigationModel
    @StateObject private var onboardingModel = OnboardingViewModel()

    var body: some View {
        Group {
            contentBody
        }
        .frame(minWidth: 720, minHeight: 520)
        .onAppear { onboardingModel.refreshAll() }
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

private struct PipelineContentView: View {
    @StateObject private var model = MeetingPipelineViewModel.live()
    @State private var isImportingFile = false
    @State private var isDropTargeted = false
    @State private var isRecordButtonHovered = false

    var body: some View {
        VStack(spacing: 24) {
            recordControl
            importArea

            Spacer(minLength: 0)
        }
        .padding(24)
        .onAppear { model.refreshVaultStatus() }
        .onReceive(model.$state) { state in
            if case .done = state {
                model.send(.reset)
            }
        }
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.audio, .movie]) { result in
            switch result {
            case .success(let url):
                importFile(url)
            case .failure:
                break
            }
        }
    }

    private var importArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Import")
                .font(.title3.bold())

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isDropTargeted ? Color.accentColor : Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.gray.opacity(0.06)))

                VStack(spacing: 8) {
                    Text("Drop an audio or video file")
                        .foregroundStyle(.secondary)

                    Button("Choose File…") {
                        isImportingFile = true
                    }
                    .disabled(!model.state.canImportMedia)
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recordControl: some View {
        Button(action: handleRecordButtonTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.2, green: 0.5, blue: 1.0), Color(red: 0.1, green: 0.35, blue: 0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        if recordButtonShowsSpinner {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else if let iconName = recordButtonIconName {
                            Image(systemName: iconName)
                                .font(.title3.weight(.semibold))
                        }

                        Text(recordButtonTitle)
                            .font(.title3.bold())
                    }
                    .foregroundStyle(.white)

                    if recordButtonShowsWaveform {
                        AudioWaveformView(levels: model.audioLevelSamples)
                            .frame(height: 36)
                    }
                }
                .padding(.vertical, 22)
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 12)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isRecordButtonHovered = hovering
        }
        .disabled(!recordButtonEnabled)
        .opacity(recordButtonEnabled ? 1 : 0.6)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard model.state.canImportMedia else { return false }

        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { continue }

            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }

                guard let url, isSupportedMediaURL(url) else { return }
                Task { @MainActor in
                    importFile(url)
                }
            }
            return true
        }

        return false
    }

    private func isSupportedMediaURL(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .audio) || type.conforms(to: .movie)
    }

    private func importFile(_ url: URL) {
        model.send(.importFile(url))
    }

    private var recordButtonState: RecordButtonState {
        switch model.state {
        case .recording:
            return .recording
        case .recorded:
            return .recorded
        case .processing, .writing, .importing:
            return .processing
        case .idle, .done, .failed:
            return .ready
        }
    }

    private var recordButtonTitle: String {
        switch recordButtonState {
        case .ready:
            return "Start recording"
        case .recording:
            return isRecordButtonHovered ? "Stop recording" : "Recording..."
        case .recorded:
            return "Process"
        case .processing:
            return "Processing"
        }
    }

    private var recordButtonIconName: String? {
        switch recordButtonState {
        case .ready:
            return "mic.fill"
        case .recording:
            return "mic.fill"
        case .recorded:
            return "sparkles"
        case .processing:
            return nil
        }
    }

    private var recordButtonShowsSpinner: Bool {
        if case .processing = recordButtonState {
            return true
        }
        return false
    }

    private var recordButtonShowsWaveform: Bool {
        if case .recording = recordButtonState {
            return true
        }
        return false
    }

    private var recordButtonEnabled: Bool {
        switch recordButtonState {
        case .ready:
            return true
        case .recording:
            return true
        case .recorded:
            return model.state.canProcess
        case .processing:
            return false
        }
    }

    private func handleRecordButtonTap() {
        switch model.state {
        case .idle:
            model.send(.startRecording)
        case .recording:
            model.send(.stopRecording)
        case .recorded:
            model.send(.process)
        case .done, .failed:
            model.send(.reset)
            model.send(.startRecording)
        default:
            break
        }
    }

}

private enum RecordButtonState {
    case ready
    case recording
    case recorded
    case processing
}

private struct AudioWaveformView: View {
    let levels: [CGFloat]

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let count = max(levels.count, 1)
            let barWidth = max((proxy.size.width / CGFloat(count)) - 4, 4)

            HStack(alignment: .center, spacing: 4) {
                ForEach(levels.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.85))
                        .frame(
                            width: barWidth,
                            height: max(6, levels[index] * height)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppNavigationModel())
}
