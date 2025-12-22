//
//  ContentView.swift
//  Minute
//
//  Created by Robert Holst on 12/19/25.
//

import AppKit
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
        .background(WindowChromeAccessor { window in
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
        })
        .onAppear { onboardingModel.refreshAll() }
    }

    @ViewBuilder
    private var contentBody: some View {
        if onboardingModel.isComplete {
            switch appState.mainContent {
            case .pipeline:
                PipelineContentView()
            case .settings:
                MainSettingsView()
            }
        } else {
            OnboardingView(model: onboardingModel)
        }
    }
}

private struct PipelineContentView: View {
    @EnvironmentObject private var appState: AppNavigationModel
    @StateObject private var model = MeetingPipelineViewModel.live()
    @State private var isImportingFile = false
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            importArea
            controls
            statusArea
            resultsArea

            Spacer(minLength: 0)
        }
        .padding(24)
        .onAppear { model.refreshVaultStatus() }
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
            .frame(height: 120)
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Minute")
                    .font(.largeTitle.bold())

                HStack(spacing: 8) {
                    Text("Vault:")
                        .foregroundStyle(.secondary)

                    Text(model.vaultStatus.displayText)
                        .foregroundStyle(model.vaultStatus.isConfigured ? .primary : .secondary)
                        .lineLimit(1)

                    if !model.vaultStatus.isConfigured {
                        Text("(select in Settings)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.callout)
            }

            Spacer()

            Button("Settings…") {
                appState.showSettings()
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Controls")
                .font(.title3.bold())

            HStack(spacing: 12) {
                if !model.microphonePermissionGranted {
                    Button("Enable Microphone") {
                        model.requestMicrophonePermission()
                    }
                }

                if !model.screenRecordingPermissionGranted {
                    Button("Enable Screen Recording") {
                        model.requestScreenRecordingPermission()
                    }
                }

                Button("Start Recording") {
                    model.send(.startRecording)
                }
                .disabled(!model.state.canStartRecording || !model.microphonePermissionGranted || !model.screenRecordingPermissionGranted)

                Button("Stop") {
                    model.send(.stopRecording)
                }
                .disabled(!model.state.canStopRecording)

                Button("Process") {
                    model.send(.process)
                }
                .disabled(!model.state.canProcess)

                if model.state.canCancelProcessing {
                    Button("Cancel") {
                        model.send(.cancelProcessing)
                    }
                }

                if model.state.canReset {
                    Button("Reset") {
                        model.send(.reset)
                    }
                }

                Spacer()
            }
        }
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

            HStack(spacing: 12) {
                Text(model.state.statusLabel)

                if let progress = model.progress {
                    ProgressView(value: progress)
                        .frame(width: 240)
                } else if model.state.canCancelProcessing {
                    ProgressView()
                }

                Spacer()
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var resultsArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Results")
                .font(.title3.bold())

            switch model.state {
            case .done(let noteURL, let audioURL):
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Note") {
                        Text(noteURL.path)
                            .font(.caption)
                            .textSelection(.enabled)
                    }

                    LabeledContent("Audio") {
                        Text(audioURL.path)
                            .font(.caption)
                            .textSelection(.enabled)
                    }

                    HStack(spacing: 12) {
                        Button("Reveal note in Finder") { model.revealInFinder(noteURL) }
                        Button("Reveal audio in Finder") { model.revealInFinder(audioURL) }
                        Spacer()
                    }
                }

            case .failed(let error, let debugOutput):
                VStack(alignment: .leading, spacing: 8) {
                    Text(error.errorDescription ?? "Failed")
                        .foregroundStyle(.red)

                    DisclosureGroup("Debug details") {
                        Text((debugOutput?.isEmpty == false) ? debugOutput! : error.debugSummary)
                            .font(.caption)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(spacing: 12) {
                        Button("Copy debug info") { model.copyDebugInfoToClipboard() }
                        Spacer()
                    }
                }

            case .recording(let session):
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recording…")
                        .foregroundStyle(.secondary)

                    LabeledContent("Elapsed") {
                        Text(session.startedAt, style: .timer)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }

            case .recorded(let audioTempURL, let durationSeconds, let startedAt, let stoppedAt):
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ready to process")
                        .foregroundStyle(.secondary)

                    LabeledContent("Temp audio") {
                        Text(audioTempURL.path)
                            .font(.caption)
                            .textSelection(.enabled)
                    }

                    LabeledContent("Duration") {
                        Text(durationSeconds.formatted(.number.precision(.fractionLength(1))) + "s")
                            .font(.caption)
                            .textSelection(.enabled)
                    }

                    LabeledContent("Start") {
                        Text(startedAt.formatted(date: .abbreviated, time: .standard))
                            .font(.caption)
                            .textSelection(.enabled)
                    }

                    LabeledContent("Stop") {
                        Text(stoppedAt.formatted(date: .abbreviated, time: .standard))
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }

            case .importing(let sourceURL):
                VStack(alignment: .leading, spacing: 6) {
                    Text("Importing file…")
                        .foregroundStyle(.secondary)

                    LabeledContent("Source") {
                        Text(sourceURL.lastPathComponent)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }

            default:
                Text("No results yet")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct WindowChromeAccessor: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let coordinator = context.coordinator

        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window, !coordinator.didConfigure else { return }
            coordinator.didConfigure = true
            configure(window)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let coordinator = context.coordinator

        DispatchQueue.main.async { [weak nsView] in
            guard let window = nsView?.window, !coordinator.didConfigure else { return }
            coordinator.didConfigure = true
            configure(window)
        }
    }

    final class Coordinator {
        var didConfigure = false
    }
}

#Preview {
    ContentView()
        .environmentObject(AppNavigationModel())
}
