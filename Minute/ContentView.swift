//
//  ContentView.swift
//  Minute
//
//  Created by Robert Holst on 12/19/25.
//

import AppKit
import MinuteCore
import SwiftUI

struct ContentView: View {
    @StateObject private var model = MeetingPipelineViewModel.live()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            controls
            statusArea
            resultsArea

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 520)
        .onAppear { model.refreshVaultStatus() }
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
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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

            default:
                Text("No results yet")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
}
