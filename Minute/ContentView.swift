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
        .frame(minWidth: 860, minHeight: 520)
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
    @StateObject private var notesModel = MeetingNotesBrowserViewModel()
    @State private var isImportingFile = false
    @State private var isDropTargeted = false
    @State private var isRecordButtonHovered = false
    @State private var isRecordingWindowPickerPresented = false
    @AppStorage(AppDefaultsKey.screenContextEnabled) private var screenContextEnabled: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            MeetingNotesSidebarView(model: notesModel)

            Divider()

            if notesModel.isOverlayPresented {
                MarkdownViewerOverlay(
                    title: notesModel.selectedItem?.title ?? "",
                    content: notesModel.noteContent,
                    isLoading: notesModel.isLoadingContent,
                    errorMessage: notesModel.overlayErrorMessage,
                    renderPlainText: notesModel.renderPlainText,
                    onClose: notesModel.dismissOverlay,
                    onRetry: notesModel.retryLoadContent,
                    onOpenInObsidian: notesModel.openInObsidian
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                pipelineBody
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            model.refreshVaultStatus()
            notesModel.refresh()
        }
        .onReceive(model.$state) { newState in
            if case .done = newState {
                notesModel.refresh()
            }
        }
    }

    private var pipelineBody: some View {
        VStack(spacing: 24) {
            recordControl
            statusArea

            Spacer(minLength: 0)
        }
        .padding(24)
        .contentShape(Rectangle())
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.audio, .movie]) { result in
            switch result {
            case .success(let url):
                importFile(url)
            case .failure:
                break
            }
        }
        .sheet(isPresented: $isRecordingWindowPickerPresented) {
            ScreenContextRecordingPickerView { selection in
                model.send(.startRecordingWithWindow(selection))
            }
        }
    }

    private var recordControl: some View {
        HStack(spacing: 0) {
            Button(action: handleRecordButtonTap) {
                VStack(spacing: 8) {
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
                            .frame(height: 22)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isRecordButtonHovered = hovering
            }
            .disabled(!recordButtonEnabled)
            .opacity(recordButtonEnabled ? 1 : 0.6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Menu {
                Button("Upload audio file…") {
                    isImportingFile = true
                }
                .disabled(!model.state.canImportMedia)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 56, height: 70)
            .contentShape(Rectangle())
        }
        .frame(height: 70)
        .background(recordButtonBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 14, x: 0, y: 8)
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

    private var statusArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.title3.bold())

            switch model.state {
            case .done(let noteURL, _):
                HStack(spacing: 12) {
                    Text("Meeting ready.")
                        .foregroundStyle(.secondary)

                    Button("Reveal in Finder") {
                        model.revealInFinder(noteURL)
                    }
                    .minuteStandardButtonStyle()

                    Spacer()
                }

            case .failed(let error, _):
                Text(error.errorDescription ?? "Processing failed.")
                    .foregroundStyle(.red)

            default:
                HStack(spacing: 12) {
                    Text(model.state.statusLabel)
                        .foregroundStyle(.secondary)

                    if let progress = model.progress {
                        ProgressView(value: progress)
                            .frame(width: 220)
                    } else if model.state.canCancelProcessing {
                        ProgressView()
                    }

                    Spacer()
                }
            }

            if shouldShowScreenInferenceStatus, let status = model.screenInferenceStatus {
                HStack(spacing: 12) {
                    Text("Screen inference")
                        .foregroundStyle(.secondary)

                    ProgressView()
                        .progressViewStyle(.linear)
                        .frame(width: 220)

                    Text("Processed \(status.processedCount), skipped \(status.skippedCount)")
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var shouldShowScreenInferenceStatus: Bool {
        switch model.state {
        case .recording, .importing:
            return true
        default:
            return false
        }
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
        if isDropTargeted, model.state.canImportMedia {
            return "Import audio"
        }

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
        if isDropTargeted, model.state.canImportMedia {
            return "tray.and.arrow.down.fill"
        }

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

    private var recordButtonBackground: some View {
        LinearGradient(
            colors: [Color("AccentColor"), Color("AccentGradientEndColor")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
            requestStartRecording()
        case .recording:
            model.send(.stopRecording)
        case .recorded:
            model.send(.process)
        case .done, .failed:
            model.send(.reset)
            requestStartRecording()
        default:
            break
        }
    }

    private func requestStartRecording() {
        if screenContextEnabled {
            isRecordingWindowPickerPresented = true
        } else {
            model.send(.startRecording)
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
