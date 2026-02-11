import MinuteCore
import SwiftUI

struct MainSessionView: View {
    @ObservedObject var model: MeetingPipelineViewModel
    @ObservedObject var notesModel: MeetingNotesBrowserViewModel
    var bottomInset: CGFloat
    let screenContextEnabled: Bool
    let isDropTargeted: Bool
    let dropErrorMessage: String?
    let onUploadTap: () -> Void

    var body: some View {
        RecordingSessionCardView(
            model: model,
            bottomInset: bottomInset,
            screenContextEnabled: screenContextEnabled,
            isDropTargeted: isDropTargeted,
            dropErrorMessage: dropErrorMessage,
            onUploadTap: onUploadTap
        )
    }
}

struct RecordingSessionCardView: View {
    @ObservedObject var model: MeetingPipelineViewModel
    let bottomInset: CGFloat
    let screenContextEnabled: Bool
    let isDropTargeted: Bool
    let dropErrorMessage: String?
    let onUploadTap: () -> Void

    @State private var isScreenContextPopoverPresented = false

    private var microphoneBinding: Binding<Bool> {
        Binding(
            get: { model.microphoneCaptureEnabled },
            set: { model.setMicrophoneCaptureEnabled($0) }
        )
    }

    private var systemAudioBinding: Binding<Bool> {
        Binding(
            get: { model.systemAudioCaptureEnabled },
            set: { model.setSystemAudioCaptureEnabled($0) }
        )
    }

    private var isRecording: Bool {
        if case .recording = model.state { return true }
        return false
    }

    private var isListening: Bool {
        isRecording && (model.microphoneCaptureEnabled || model.systemAudioCaptureEnabled)
    }

    private var topInset: CGFloat {
        if #available(macOS 26.0, *) {
            12
        } else {
            40
        }
    }

    var body: some View {
        VStack() {
            VStack(alignment: .leading, spacing: 30) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {

                        if isRecording {
                            Text("Session in progress")
                                .font(.system(size: 20, weight: .semibold))
                                .tracking(-0.4)
                                .foregroundStyle(Color.minuteTextPrimary)
                            Text("You can continue editing your session settings.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.minuteTextSecondary)
                        } else {
                            Text("New Session")
                                .font(.system(size: 20, weight: .semibold))
                                .tracking(-0.4)
                                .foregroundStyle(Color.minuteTextPrimary)
                            Text("Configure your session and start recording.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.minuteTextSecondary)

                        }

                        if let dropErrorMessage {
                            Text(dropErrorMessage)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.red.opacity(0.9))
                                .accessibilityLabel(Text("Import error"))
                                .accessibilityValue(Text(dropErrorMessage))
                                .transition(.opacity)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Meeting Type")
                            .minuteFootnote()
                            .textCase(.uppercase)

                        Menu {
                            ForEach(MeetingType.allCases, id: \.self) { type in
                                Button(type.displayName) {
                                    model.meetingType = type
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "rectangle.grid.1x2")
                                    .foregroundStyle(Color.minuteGlow)
                                Text(model.meetingType.displayName)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Color.minuteTextPrimary)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.minuteTextSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .menuStyle(.borderlessButton)
                        .frame(maxWidth: .infinity)
                        .minuteDropdownStyle()
                        .accessibilityLabel(Text("Meeting Type"))
                        .accessibilityValue(Text(model.meetingType.displayName))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Language Processing")
                            .minuteFootnote()
                            .textCase(.uppercase)

                        Menu {
                            Button(model.autoToEnglishOptionTitle) {
                                model.languageProcessing = .autoToEnglish
                            }
                            Button(model.autoToPickedLanguageOptionTitle) {
                                model.languageProcessing = .autoPreserve
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "globe")
                                    .foregroundStyle(Color.green)
                                Text(model.selectedLanguageProcessingTitle)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Color.minuteTextPrimary)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.minuteTextSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .menuStyle(.borderlessButton)
                        .frame(maxWidth: .infinity)
                        .minuteDropdownStyle()
                        .help(model.selectedLanguageProcessingDetailText)
                        .accessibilityLabel(Text("Language Processing"))
                        .accessibilityValue(Text(model.selectedLanguageProcessingTitle))
                        .accessibilityHint(Text(model.selectedLanguageProcessingDetailText))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Audio Channels")
                            .minuteFootnote()
                            .textCase(.uppercase)

                        HStack(spacing: 14) {
                            CaptureSourceCard(
                                title: "Microphone",
                                systemImage: "mic.fill",
                                tint: Color.accentColor,
                                isOn: microphoneBinding.wrappedValue,
                                isEnabled: true,
                                action: { microphoneBinding.wrappedValue.toggle() }
                            )

                            CaptureSourceCard(
                                title: "System",
                                systemImage: "speaker.wave.2.fill",
                                tint: Color.pink,
                                isOn: systemAudioBinding.wrappedValue,
                                isEnabled: true,
                                action: { systemAudioBinding.wrappedValue.toggle() }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Screen Context")
                            .minuteFootnote()
                            .textCase(.uppercase)

                        CaptureSourceCard(
                            title: "Screen Record",
                            systemImage: model.hasScreenCaptureSelection ? "display" : "rectangle.slash",
                            tint: Color.minuteGlow,
                            isOn: model.screenCaptureEnabled && model.hasScreenCaptureSelection,
                            isEnabled: screenContextEnabled,
                            action: { isScreenContextPopoverPresented = true }
                        )
                        .popover(isPresented: $isScreenContextPopoverPresented, arrowEdge: .bottom) {
                            ScreenContextWindowPickerPopover(
                                currentSelection: model.currentScreenCaptureSelection,
                                onDismiss: {
                                    isScreenContextPopoverPresented = false
                                },
                                onSelect: { selection in
                                    if let selection {
                                        model.setScreenCaptureSelection(selection)
                                        model.setScreenCaptureEnabled(true)
                                    } else {
                                        model.setScreenCaptureSelection(nil)
                                    }
                                    isScreenContextPopoverPresented = false
                                }
                            )
                        }

                        Text(model.screenCaptureSelectionDisplayText ?? "None")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.minuteTextSecondary)
                            .lineLimit(1)
                            .accessibilityLabel(Text("Selected window"))
                            .accessibilityValue(Text(model.screenCaptureSelectionDisplayText ?? "None"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Group {
                if case .recording(let session) = model.state {
                    RecordingSessionView(
                        session: session,
                        levels: model.audioLevelSamples,
                        isListening: isListening
                    )
                } else if model.state.canImportMedia {
                    SessionDropZoneView(
                        isHighlighted: isDropTargeted,
                        onUploadTap: onUploadTap
                    )
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "waveform")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.minuteTextSecondary)

                        Text(model.state.statusLabel)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.minuteTextPrimary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: 220)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 22)
        .padding(.top, topInset)
        .padding(.bottom, 22 + bottomInset)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct RecordingSessionView: View {
    let session: RecordingSession
    let levels: [CGFloat]
    let isListening: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            Text(isListening ? "Listening" : "Not listening (mic and system audio are off)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isListening ? Color.minuteTextSecondary : Color.orange)

            Spacer(minLength: 0)

            WaveformRibbonView(levels: levels)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(height: 180)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct SessionDropZoneView: View {
    let isHighlighted: Bool
    let onUploadTap: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isHighlighted ? Color.minuteGlow : Color.minuteTextSecondary)

            VStack(spacing: 4) {
                Text("Drop audio or video")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.minuteTextPrimary)

                Text("Or upload a file to start processing")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.minuteTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    isHighlighted ? Color.minuteGlow.opacity(0.8) : Color.minuteOutline,
                    style: StrokeStyle(lineWidth: isHighlighted ? 2 : 1, dash: [8, 6])
                )
        )
        .animation(.easeInOut(duration: 0.15), value: isHighlighted)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            onUploadTap()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Upload recording"))
        .accessibilityHint(Text("Click to browse for a file, or drag and drop a recording."))
    }
}

private struct CaptureSourceCard: View {
    let title: String
    let systemImage: String
    let tint: Color
    let isOn: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.minuteSurfaceStrong)
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isEnabled ? (isOn ? tint : Color.minuteTextMuted) : Color.minuteTextMuted)
                }
                .frame(width: 46, height: 46)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isEnabled ? (isOn ? tint : Color.minuteTextSecondary) : Color.minuteTextMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isEnabled ? (isOn ? Color.minuteSurfaceStrong : Color.minuteSurface) : Color.minuteSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isEnabled ? (isOn ? tint.opacity(0.55) : Color.minuteOutline) : Color.minuteOutline,
                        lineWidth: isOn ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct PulsingDot: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(Color.red.opacity(0.5), lineWidth: 6)
                    .scaleEffect(isPulsing ? 1.5 : 0.6)
                    .opacity(isPulsing ? 0 : 0.6)
            )
            .onAppear {
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
    }
}

struct WaveformRibbonView: View {
    let levels: [CGFloat]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let count = max(levels.count, 1)
                let midY = size.height / 2
                let phase = CGFloat(timeline.date.timeIntervalSinceReferenceDate)

                var path = Path()
                for index in 0..<count {
                    let x = size.width * CGFloat(index) / CGFloat(max(count - 1, 1))
                    let level = max(min(levels[safe: index] ?? 0, 1), 0.05)
                    let wave = sin(CGFloat(index) * 0.35 + phase) * level
                    let y = midY + wave * midY * 0.9
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 8))
                    layer.stroke(
                        path,
                        with: .linearGradient(
                            MinuteTheme.waveformGradient,
                            startPoint: .zero,
                            endPoint: CGPoint(x: size.width, y: 0)
                        ),
                        lineWidth: 10
                    )
                }

                context.stroke(
                    path,
                    with: .linearGradient(
                        MinuteTheme.waveformGradient,
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: 0)
                    ),
                    lineWidth: 3
                )
            }
        }
    }
}

private extension Array where Element == CGFloat {
    subscript(safe index: Int) -> CGFloat? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

#Preview(traits: .fixedLayout(width: 1024, height: 800)) {
    RecordingSessionCardView(
        model: MeetingPipelineViewModel.live(),
        bottomInset: 104,
        screenContextEnabled: true,
        isDropTargeted: false,
        dropErrorMessage: nil,
        onUploadTap: {}
    )
    .frame(width: 1024, height: 800)
    .background(MinuteTheme.windowBackground)
}
