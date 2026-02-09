//
//  ContentView.swift
//  Minute
//
//  Created by Robert Holst on 12/19/25.
//

import MinuteCore
import SwiftUI
import UniformTypeIdentifiers
import Combine

struct ContentView: View {
    @EnvironmentObject private var appState: AppNavigationModel
    @StateObject private var onboardingModel = OnboardingViewModel()

    var body: some View {
        Group {
            contentBody
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(MinuteTheme.windowBackground)
        .onAppear {
            onboardingModel.refreshAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: .minuteMicActivityShowPipeline)) { _ in
            appState.showPipeline()
        }
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
    @AppStorage(AppDefaultsKey.screenContextEnabled)
    private var screenContextEnabled: Bool = AppConfiguration.Defaults.defaultScreenContextEnabled
    @AppStorage(AppDefaultsKey.micActivityNotificationsEnabled)
    private var micActivityNotificationsEnabled: Bool = AppConfiguration.Defaults.defaultMicActivityNotificationsEnabled
    @State private var micActivityCoordinator = MicActivityNotificationCoordinator()
    @FocusState private var recordButtonFocused: Bool
    @State private var isImportingFile = false
    @State private var isDropTargeted = false
    @State private var isRecordingWindowPickerPresented = false
    @State private var screenPickerPurpose: ScreenPickerPurpose?
    @State private var screenTogglePending = false
    @State private var screenPickerHandled = false
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    private let compactHeightThreshold: CGFloat = 620
    private let floatingBarHeight: CGFloat = 88

    var body: some View {
        GeometryReader { proxy in
            let isCompactLayout = proxy.size.height < compactHeightThreshold

            ZStack(alignment: .bottom) {
                NavigationSplitView(columnVisibility: $sidebarVisibility) {
                    MeetingNotesSidebarView(model: notesModel)
                        .navigationSplitViewColumnWidth(min: 320, ideal: 320, max: 320)
                } detail: {
                    ZStack(alignment: .topTrailing) {
                        mainStage(bottomInset: mainStageBottomInset(isCompact: isCompactLayout))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                    .overlay(dropOverlay)
                }
                .background(MinuteTheme.windowBackground)
                .toolbar(removing: .sidebarToggle)
                .navigationSplitViewStyle(.balanced)

                GeometryReader { geometry in
                    floatingControlBar
                        .frame(width: geometry.size.width * 0.7, alignment: .center)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: floatingBarHeight, alignment: .bottom)
                .padding(.bottom, isCompactLayout ? 12 : 22)

                if let status = statusDrawerModel {
                    StatusDrawerView(model: status, isCompact: isCompactLayout)
                        .frame(maxWidth: 560)
                        .padding(.bottom, statusDrawerBottomPadding(isCompact: isCompactLayout))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.2), value: statusDrawerModel != nil)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
            .clipped()
            .background(MinuteTheme.windowBackground)
            .onAppear {
                model.refreshVaultStatus()
                notesModel.refresh()
                micActivityCoordinator.setEnabled(micActivityNotificationsEnabled)
                micActivityCoordinator.updatePipelineState(model.state)
            }
            .onDisappear {
                micActivityCoordinator.stop()
            }
            .onReceive(model.$state) { newState in
                if case let .done(noteURL, _) = newState {
                    notesModel.refreshAndSelect(noteURL: noteURL)
                }
                micActivityCoordinator.updatePipelineState(newState)
            }
            .onReceive(model.$lastBackgroundProcessedNoteURL.compactMap { $0 }) { noteURL in
                notesModel.refreshAndSelect(noteURL: noteURL)
            }
            .onChange(of: micActivityNotificationsEnabled) { _, newValue in
                micActivityCoordinator.setEnabled(newValue)
            }
            .contentShape(Rectangle())
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers)
            }
            .fileImporter(isPresented: $isImportingFile, allowedContentTypes: importableContentTypes) { result in
                switch result {
                case .success(let url):
                    importFile(url)
                case .failure:
                    break
                }
            }
            .sheet(isPresented: $isRecordingWindowPickerPresented) {
                ScreenContextRecordingPickerView { selection in
                    screenPickerHandled = true
                    handleScreenSelection(selection)
                }
                .onDisappear(perform: handleScreenPickerDismiss)
            }
            .onChange(of: screenContextEnabled) { _, newValue in
                handleScreenContextSettingChange(newValue)
            }
            .onReceive(NotificationCenter.default.publisher(for: .minuteMicActivityStartRecording)) { _ in
                handleNotificationStartRecording()
            }
        }
    }

    @ViewBuilder
    private var dropOverlay: some View {
        if isDropTargeted, model.state.canImportMedia {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.minuteGlow.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [10]))
                .padding(32)
                .overlay(
                    Text("Drop audio or video to import")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(Color.minuteTextPrimary)
                        .padding(10)
                        .background(
                            Capsule()
                                .fill(Color.minuteSurface)
                        )
                )
                .transition(.opacity)
        }
    }

    private func mainStage(bottomInset: CGFloat) -> some View {
        MainStageContainer {
            if notesModel.isOverlayPresented {
                MarkdownViewerOverlay(
                    title: notesModel.selectedItem?.title ?? "",
                    summaryContent: notesModel.noteContent,
                    transcriptContent: notesModel.transcriptDisplayContent ?? notesModel.transcriptContent,
                    rawTranscriptContent: notesModel.transcriptContent,
                    isLoadingSummary: notesModel.isLoadingContent,
                    isLoadingTranscript: notesModel.isLoadingTranscript,
                    summaryErrorMessage: notesModel.overlayErrorMessage,
                    transcriptErrorMessage: notesModel.transcriptErrorMessage,
                    renderSummaryPlainText: notesModel.renderPlainText,
                    renderTranscriptPlainText: notesModel.renderTranscriptPlainText,
                    hasTranscript: notesModel.selectedItem?.hasTranscript ?? false,
                    selectedTab: notesModel.selectedTab,
                    onSelectTab: notesModel.selectTab,
                    onClose: notesModel.dismissOverlay,
                    onRetry: { tab in
                        notesModel.retryLoadContent(for: tab)
                    },
                    onOpenInObsidian: notesModel.openInObsidian,
                    onOpenSummaryInObsidian: {
                        guard let item = notesModel.selectedItem else { return }
                        notesModel.openSummaryInObsidian(for: item)
                    },
                    onOpenTranscriptInObsidian: {
                        guard let item = notesModel.selectedItem else { return }
                        notesModel.openTranscriptInObsidian(for: item)
                    },
                    onRevealInFinder: {
                        guard let item = notesModel.selectedItem else { return }
                        notesModel.revealInFinder(for: item)
                    },
                    onDelete: {
                        guard let item = notesModel.selectedItem else { return }
                        notesModel.delete(item)
                    },
                    speakerEditor: MarkdownViewerOverlay.SpeakerEditorConfig(
                        speakerIDs: notesModel.speakerIDs,
                        speakerName: { notesModel.speakerName(for: $0) },
                        setSpeakerName: { id, name in notesModel.setSpeakerName(name, for: id) },
                        knownSpeakerProfileNames: notesModel.knownSpeakerProfileNames,
                        save: notesModel.saveSpeakerNames,
                        isSaving: notesModel.isSavingSpeakerNames,
                        errorMessage: notesModel.speakerSaveErrorMessage,
                        enrollmentErrorMessage: notesModel.speakerEnrollmentErrorMessage,
                        enrollKnownSpeaker: { notesModel.enrollKnownSpeaker(speakerId: $0) },
                        isEnrollingKnownSpeaker: { notesModel.enrollingSpeakerID == $0 },
                        isKnownSpeaker: { notesModel.isKnownSpeaker(speakerId: $0) },
                        knownSpeakerName: { notesModel.knownSpeakerName(speakerId: $0) },
                        isRewritingTranscriptHeadings: notesModel.isRewritingTranscriptHeadings,
                        rewriteErrorMessage: notesModel.speakerTranscriptRewriteErrorMessage
                    )
                )
            } else {
                MainStageView(
                    model: model,
                    notesModel: notesModel,
                    bottomInset: bottomInset
                )
            }
        }
    }

    private var floatingControlBar: some View {
        FloatingControlBar(
            recordState: recordButtonState,
            recordEnabled: recordButtonEnabled,
            audioMode: audioCaptureMode,
            isScreenShareOn: isScreenToggleOn,
            showsScreenShareControl: screenContextEnabled,
            controlsEnabled: captureTogglesEnabled,
            uploadEnabled: model.state.canImportMedia,
            recordFocus: $recordButtonFocused,
            onRecordTap: handleRecordButtonTap,
            onAudioModeChange: setAudioCaptureMode,
            onScreenShareToggle: { handleScreenToggleChange(!isScreenToggleOn) },
            onUploadTap: { isImportingFile = true },
            meetingType: $model.meetingType
        )
        .animation(.easeInOut(duration: 0.2), value: statusDrawerModel != nil)
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
        let ext = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ext == "wav" || ext == "wave" {
            return true
        }
        guard let type = UTType(filenameExtension: ext) else { return false }
        return type.conforms(to: .audio) || type.conforms(to: .movie)
    }

    private var importableContentTypes: [UTType] {
        var types: [UTType] = [.audio, .movie]
        if let wav = UTType(filenameExtension: "wav") {
            types.append(wav)
        }
        return types
    }

    private func importFile(_ url: URL) {
        model.send(.importFile(url))
    }

    private var isScreenToggleOn: Bool {
        screenContextEnabled && (model.screenCaptureEnabled || screenTogglePending)
    }

    private var captureTogglesEnabled: Bool {
        switch model.state {
        case .idle, .recording, .recorded, .done, .failed:
            return true
        default:
            return false
        }
    }

    private var audioCaptureMode: AudioCaptureMode {
        switch (model.microphoneCaptureEnabled, model.systemAudioCaptureEnabled) {
        case (true, true):
            return .both
        case (true, false):
            return .room
        case (false, true):
            return .online
        case (false, false):
            return .room
        }
    }

    private func setAudioCaptureMode(_ mode: AudioCaptureMode) {
        model.setAudioCaptureConfiguration(
            microphoneEnabled: mode.microphoneEnabled,
            systemAudioEnabled: mode.systemAudioEnabled
        )
    }

    private var recordButtonState: RecordButtonState {
        switch model.captureState {
        case .recording:
            return .recording
        case .ready:
            return .ready
        }
    }

    private var recordButtonEnabled: Bool {
        switch recordButtonState {
        case .ready:
            return true
        case .recording:
            return true
        }
    }

    private var statusDrawerModel: StatusDrawerModel? {
        if model.backgroundProcessingSnapshot.activeMeetingID != nil {
            let stage = model.backgroundProcessingSnapshot.activeStage
            let progress = model.backgroundProcessingSnapshot.activeProgress
            let isDeferred = model.screenInferenceStatus?.isFirstInferenceDeferred == true
            let hasPending = model.backgroundProcessingSnapshot.pendingMeetingID != nil

            let title: String
            switch stage {
            case .downloadingModels:
                title = "Downloading Models"
            case .transcribing:
                title = "Transcribing"
            case .summarizing:
                title = "Summarizing"
            case .writing:
                title = "Writing"
            case nil:
                title = "Processing"
            }

            let baseDetail = isDeferred
                ? "Your recorded meeting is processing. Screen context disabled until processing is done."
                : "Your recorded meeting is processing in the background."

            let detail = hasPending
                ? baseDetail + " Another meeting is pending next."
                : baseDetail

            return StatusDrawerModel(
                title: title,
                detail: detail,
                progress: progress,
                showsActivity: progress == nil,
                isError: false,
                actionTitle: "Cancel",
                action: { model.cancelBackgroundProcessing(clearPending: true) },
                secondaryActionTitle: nil,
                secondaryAction: nil
            )
        }

        if case .idle = model.state {
            switch model.backgroundProcessingSnapshot.lastOutcome {
            case .failed(let message):
                return StatusDrawerModel(
                    title: "Background processing failed",
                    detail: message,
                    progress: nil,
                    showsActivity: false,
                    isError: true,
                    actionTitle: "Retry",
                    action: { model.retryBackgroundProcessing() },
                    secondaryActionTitle: nil,
                    secondaryAction: nil
                )
            case .canceled:
                return StatusDrawerModel(
                    title: "Background processing canceled",
                    detail: "You can retry this meeting later.",
                    progress: nil,
                    showsActivity: false,
                    isError: false,
                    actionTitle: "Retry",
                    action: { model.retryBackgroundProcessing() },
                    secondaryActionTitle: nil,
                    secondaryAction: nil
                )
            case .completed, nil:
                break
            }
        }

        if case .idle = model.state,
           let recovery = model.recoverableRecordings.first {
            let folderName = recovery.sessionURL.lastPathComponent
            return StatusDrawerModel(
                title: "Unfinished meeting detected",
                detail: "An unfinished meeting was detected in \(folderName). Do you want to recover it?",
                progress: nil,
                showsActivity: false,
                isError: false,
                actionTitle: "Recover",
                action: { model.recoverRecording(recovery) },
                secondaryActionTitle: "Delete",
                secondaryAction: { model.discardRecoverableRecording(recovery) }
            )
        }
        switch model.state {
        case .recorded:
            return StatusDrawerModel(
                title: "Recording ready",
                detail: "This meeting is ready to process.",
                progress: nil,
                showsActivity: false,
                isError: false,
                actionTitle: "Process",
                action: { model.send(.process) },
                secondaryActionTitle: nil,
                secondaryAction: nil
            )
        case .processing, .writing, .importing:
            return StatusDrawerModel(
                title: model.state.statusLabel,
                detail: "Meeting is being processed.",
                progress: model.progress,
                showsActivity: model.progress == nil,
                isError: false,
                actionTitle: nil,
                action: nil,
                secondaryActionTitle: nil,
                secondaryAction: nil
            )
        case .done(let noteURL, _):
            return StatusDrawerModel(
                title: "Meeting ready",
                detail: "Your note, transcript, and audio are in the vault.",
                progress: nil,
                showsActivity: false,
                isError: false,
                actionTitle: "Reveal in Finder",
                action: { model.revealInFinder(noteURL) },
                secondaryActionTitle: nil,
                secondaryAction: nil
            )
        case .failed(let error, _):
            return StatusDrawerModel(
                title: "Processing failed",
                detail: ErrorHandler.userMessage(for: error, fallback: "Processing failed."),
                progress: nil,
                showsActivity: false,
                isError: true,
                actionTitle: nil,
                action: nil,
                secondaryActionTitle: nil,
                secondaryAction: nil
            )
        default:
            return nil
        }
    }

    private func mainStageBottomInset(isCompact: Bool) -> CGFloat {
        let base: CGFloat = isCompact ? 88 : 104
        let statusExtra: CGFloat = statusDrawerModel == nil ? 0 : (isCompact ? 64 : 84)
        return base + statusExtra
    }

    private func statusDrawerBottomPadding(isCompact: Bool) -> CGFloat {
        let spacing: CGFloat = isCompact ? 6 : 10
        let bottomPadding: CGFloat = isCompact ? 12 : 22
        return bottomPadding + floatingBarHeight + spacing
    }

    private func handleRecordButtonTap() {
        switch model.captureState {
        case .ready:
            requestStartRecording()
        case .recording:
            model.send(.stopRecording)
        }
    }

    private func handleNotificationStartRecording() {
        if model.captureState == .ready {
            handleRecordButtonTap()
        }
    }

    private func requestStartRecording() {
        if screenContextEnabled && model.screenCaptureEnabled {
            presentScreenPicker(for: .startRecording)
        } else {
            model.send(.startRecording)
        }
    }

    private func handleScreenToggleChange(_ enabled: Bool) {
        guard screenContextEnabled else { return }
        if enabled {
            if model.captureState == .recording {
                if model.hasScreenCaptureSelection {
                    model.setScreenCaptureEnabled(true)
                } else {
                    screenTogglePending = true
                    presentScreenPicker(for: .enableDuringRecording)
                }
            } else {
                model.setScreenCaptureEnabled(true)
            }
        } else {
            screenTogglePending = false
            model.setScreenCaptureEnabled(false)
        }
    }

    private func handleScreenContextSettingChange(_ enabled: Bool) {
        if !enabled {
            screenTogglePending = false
            isRecordingWindowPickerPresented = false
            screenPickerPurpose = nil
            screenPickerHandled = false
        }
        model.setScreenCaptureEnabled(enabled)
    }

    private func presentScreenPicker(for purpose: ScreenPickerPurpose) {
        screenPickerPurpose = purpose
        screenPickerHandled = false
        isRecordingWindowPickerPresented = true
    }

    private func handleScreenSelection(_ selection: ScreenContextWindowSelection) {
        guard screenContextEnabled else { return }
        guard let purpose = screenPickerPurpose else { return }
        switch purpose {
        case .startRecording:
            model.send(.startRecordingWithWindow(selection))
        case .enableDuringRecording:
            model.setScreenCaptureSelection(selection)
            model.setScreenCaptureEnabled(true)
            screenTogglePending = false
        }
        screenPickerPurpose = nil
    }

    private func handleScreenPickerDismiss() {
        guard let purpose = screenPickerPurpose else { return }
        if purpose == .enableDuringRecording && !screenPickerHandled {
            screenTogglePending = false
        }
        screenPickerPurpose = nil
        screenPickerHandled = false
    }

}

private enum RecordButtonState {
    case ready
    case recording
}

private enum ScreenPickerPurpose {
    case startRecording
    case enableDuringRecording
}

private struct MainStageContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var topInset: CGFloat {
        if #available(macOS 26.0, *) {
            12
        } else {
            20
        }
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .safeAreaPadding(.top, topInset)
    }
}

private struct MainStageView: View {
    @ObservedObject var model: MeetingPipelineViewModel
    @ObservedObject var notesModel: MeetingNotesBrowserViewModel
    var bottomInset: CGFloat

    private static let totalDurationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter
    }()

    var body: some View {
        Group {
            if case .recording(let session) = model.state {
                RecordingStageView(
                    session: session,
                    levels: model.audioLevelSamples
                )
            } else {
                DailyBriefingView(
                    greeting: greeting,
                    meetingCount: notesModel.notes.count,
                    totalMinutesText: totalMinutesText
                )
            }
        }
        .padding(.bottom, bottomInset)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning."
        case 12..<17:
            return "Good afternoon."
        case 17..<22:
            return "Good evening."
        default:
            return "Welcome back."
        }
    }

    private var totalMinutesText: String {
        let durations = notesModel.notePreviews.values.compactMap(\.durationSeconds)
        guard !durations.isEmpty else { return "--" }
        let total = durations.reduce(0, +)
        return Self.totalDurationFormatter.string(from: total) ?? "--"
    }

}

private struct DailyBriefingView: View {
    let greeting: String
    let meetingCount: Int
    let totalMinutesText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Daily Briefing")
                    .minuteFootnote()
                    .textCase(.uppercase)

                Text(greeting)
                    .font(.system(size: 28, weight: .semibold))
                    .tracking(-0.6)
                    .foregroundStyle(Color.minuteTextPrimary)

                Text("\(meetingCount) sessions on record.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.minuteTextSecondary)
            }

            HStack(spacing: 12) {
                StatCard(title: "Total Meetings", value: "\(meetingCount)")
                StatCard(title: "Total Minutes", value: totalMinutesText)
            }

            EmptyStateCard(
                title: "Select a note to view details",
                subtitle: "Pick a meeting from the timeline to see its summary, transcript, and audio."
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .minuteFootnote()
                .textCase(.uppercase)

            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .tracking(-0.4)
                .foregroundStyle(Color.minuteTextPrimary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .minuteGlassPanel(cornerRadius: 16, fill: Color.minuteSurface, border: Color.minuteOutline, shadowOpacity: 0.2)
    }
}

private struct EmptyStateCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.minuteTextPrimary)

            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.minuteTextSecondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .minuteGlassPanel(cornerRadius: 18, fill: Color.minuteSurface, border: Color.minuteOutline, shadowOpacity: 0.15)
    }
}

private struct StatusDrawerModel {
    let title: String
    let detail: String
    let progress: Double?
    let showsActivity: Bool
    let isError: Bool
    let actionTitle: String?
    let action: (() -> Void)?
    let secondaryActionTitle: String?
    let secondaryAction: (() -> Void)?
}

private struct StatusDrawerView: View {
    let model: StatusDrawerModel
    let isCompact: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: isCompact ? 4 : 6) {
                Text(model.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(model.isError ? Color.red.opacity(0.9) : Color.minuteTextPrimary)

                Text(model.detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.minuteTextSecondary)
                    .lineLimit(isCompact ? 1 : nil)
                    .truncationMode(.tail)

                if let progress = model.progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                } else if model.showsActivity {
                    ProgressView()
                        .progressViewStyle(.linear)
                }
            }

            Spacer(minLength: 0)

            if let actionTitle = model.actionTitle, let action = model.action {
                HStack(spacing: 8) {
                    if let secondaryTitle = model.secondaryActionTitle,
                       let secondaryAction = model.secondaryAction {
                        Button(secondaryTitle) {
                            secondaryAction()
                        }
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .foregroundStyle(Color.minuteTextPrimary)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.minuteOutline, lineWidth: 1)
                        )
                    }

                    Button(actionTitle) {
                        action()
                    }
                    .minuteStandardButtonStyle()
                }
            }
        }
        .padding(isCompact ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .minuteGlassPanel(
            cornerRadius: 16,
            fill: Color.minuteSurfaceStrong,
            border: model.isError ? Color.red.opacity(0.6) : Color.minuteOutline,
            shadowOpacity: 0.2
        )
    }
}

private struct RecordingStageView: View {
    let session: RecordingSession
    let levels: [CGFloat]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            RecordingHeaderView(startedAt: session.startedAt)

            Spacer(minLength: 0)

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.minuteSurfaceStrong)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.minuteOutline, lineWidth: 1)
                    )

                WaveformRibbonView(levels: levels)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .frame(height: 180)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct RecordingHeaderView: View {
    let startedAt: Date

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Recording in progress")
                    .font(.system(size: 20, weight: .semibold))
                    .tracking(-0.4)
                    .foregroundStyle(Color.minuteTextPrimary)
            }

            Spacer()

            HStack(spacing: 8) {
                PulsingDot()
                RecordingTimerView(startedAt: startedAt)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.minuteSurface)
            )
        }
        .padding(.top, 8)
    }
}

private struct PulsingDot: View {
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

private struct RecordingTimerView: View {
    let startedAt: Date

    private static let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(startedAt))
            let label = Self.formatter.string(from: elapsed) ?? "00:00"
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.minuteTextPrimary)
        }
    }
}


private struct WaveformRibbonView: View {
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

private struct FloatingControlBar: View {
    let recordState: RecordButtonState
    let recordEnabled: Bool
    let audioMode: AudioCaptureMode
    let isScreenShareOn: Bool
    let showsScreenShareControl: Bool
    let controlsEnabled: Bool
    let uploadEnabled: Bool
    let recordFocus: FocusState<Bool>.Binding
    let onRecordTap: () -> Void
    let onAudioModeChange: (AudioCaptureMode) -> Void
    let onScreenShareToggle: () -> Void
    let onUploadTap: () -> Void
    @Binding var meetingType: MeetingType
    @State private var showMeetingTypePicker = false

    var body: some View {
        ZStack {
            HStack(spacing: 16) {
                AudioModeControl(
                    selection: audioMode,
                    isEnabled: controlsEnabled,
                    onSelect: onAudioModeChange
                )
                
                Spacer(minLength: 24)

                ControlBarIconButton(
                    systemName: "doc.text.fill",
                    label: "Meeting type",
                    isActive: false,
                    isEnabled: controlsEnabled || recordState == .recording,
                    action: { showMeetingTypePicker.toggle() }
                )
                .popover(isPresented: $showMeetingTypePicker, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(MeetingType.allCases, id: \.self) { type in
                            Button {
                                meetingType = type
                                showMeetingTypePicker = false
                            } label: {
                                HStack {
                                    Text(type.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if meetingType == type {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.primary.opacity(0.05))
                                    .opacity(0)
                            )
                        }
                    }
                    .padding(.vertical, 8)
                    .frame(minWidth: 200)
                }

                HStack(spacing: 12) {
                    if showsScreenShareControl {
                        ControlBarIconButton(
                            systemName: isScreenShareOn ? "display" : "rectangle.slash",
                            label: "Screen share toggle",
                            isActive: isScreenShareOn,
                            isEnabled: controlsEnabled,
                            action: onScreenShareToggle
                        )
                    }

                    ControlBarIconButton(
                        systemName: "tray.and.arrow.up.fill",
                        label: "Upload file",
                        isActive: false,
                        isEnabled: uploadEnabled,
                        action: onUploadTap
                    )
                }
            }

            RecordControlButton(
                state: recordState,
                isEnabled: recordEnabled,
                focusBinding: recordFocus,
                action: onRecordTap
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 12)
    }
}

private enum AudioCaptureMode: String, CaseIterable, Identifiable {
    case room
    case online
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .room:
            return "Room"
        case .online:
            return "Online"
        case .both:
            return "Both"
        }
    }

    var iconName: String {
        switch self {
        case .room:
            return "mic.fill"
        case .online:
            return "speaker.wave.2.fill"
        case .both:
            return "dot.radiowaves.left.and.right"
        }
    }

    var helpText: String {
        switch self {
        case .room:
            return "Room meeting (mic only)"
        case .online:
            return "Online meeting (system audio only)"
        case .both:
            return "Record mic + system audio (use headphones to avoid echo)"
        }
    }

    var microphoneEnabled: Bool {
        switch self {
        case .room, .both:
            return true
        case .online:
            return false
        }
    }

    var systemAudioEnabled: Bool {
        switch self {
        case .online, .both:
            return true
        case .room:
            return false
        }
    }
}

private struct AudioModeControl: View {
    let selection: AudioCaptureMode
    let isEnabled: Bool
    let onSelect: (AudioCaptureMode) -> Void

    var body: some View {
        let modes = Array(AudioCaptureMode.allCases.enumerated())
        HStack(spacing: 0) {
            ForEach(modes, id: \.element.id) { index, mode in
                let isSelected = (mode == selection)
                Button(action: { onSelect(mode) }) {
                    HStack(spacing: 6) {
                        Image(systemName: mode.iconName)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.minuteTextSecondary)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
                    .background(
                        selectionBackground(isSelected: isSelected, isLeading: index == 0, isTrailing: index == modes.count - 1)
                    )
                }
                .buttonStyle(.plain)
                .help(mode.helpText)
                .accessibilityLabel(Text(mode.helpText))

                if index < modes.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 1, height: 18)
                }
            }
        }
        .frame(height: 34)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
        .clipShape(Capsule())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }

    private func selectionBackground(isSelected: Bool, isLeading: Bool, isTrailing: Bool) -> some View {
        let radius: CGFloat = 16
        return Group {
            if isSelected {
                Rectangle()
                    .fill(Color.minuteGlow.opacity(0.35))
                    .mask(
                        RoundedCornerMask(
                            topLeft: isLeading ? radius : 0,
                            bottomLeft: isLeading ? radius : 0,
                            topRight: isTrailing ? radius : 0,
                            bottomRight: isTrailing ? radius : 0
                        )
                    )
            } else {
                Color.clear
            }
        }
    }
}

private struct RoundedCornerMask: Shape {
    let topLeft: CGFloat
    let bottomLeft: CGFloat
    let topRight: CGFloat
    let bottomRight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tl = min(min(topLeft, rect.width / 2), rect.height / 2)
        let tr = min(min(topRight, rect.width / 2), rect.height / 2)
        let bl = min(min(bottomLeft, rect.width / 2), rect.height / 2)
        let br = min(min(bottomRight, rect.width / 2), rect.height / 2)

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

private struct ControlBarIconButton: View {
    let systemName: String
    let label: String
    let isActive: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isActive ? Color.white : Color.minuteTextSecondary)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(isActive ? Color.minuteGlow.opacity(0.35) : Color.white.opacity(0.06))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isActive ? 0.4 : 0.16), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .help(label)
        .accessibilityLabel(Text(label))
    }
}

private struct RecordControlButton: View {
    let state: RecordButtonState
    let isEnabled: Bool
    let focusBinding: FocusState<Bool>.Binding
    let action: () -> Void

    @State private var isPulsing = false

    private var iconName: String {
        switch state {
        case .ready:
            return "mic.fill"
        case .recording:
            return "stop.fill"
        }
    }

    private var helpText: String {
        switch state {
        case .ready:
            return "Start recording"
        case .recording:
            return "Stop recording"
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .ready:
            return Color.white
        case .recording:
            return Color.red
        }
    }

    private var iconColor: Color {
        switch state {
        case .ready:
            return Color.minuteInk
        case .recording:
            return Color.white
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 58, height: 58)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)

                if state == .recording {
                    Circle()
                        .stroke(Color.red.opacity(0.35), lineWidth: 6)
                        .frame(width: 58, height: 58)
                        .scaleEffect(isPulsing ? 1.4 : 0.9)
                        .opacity(isPulsing ? 0 : 0.8)
                }
            }
            .frame(width: 64, height: 64)
        }
        .buttonStyle(.plain)
        .focused(focusBinding)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.6)
        .help(helpText)
        .accessibilityLabel(Text(helpText))
        .onAppear {
            if state == .recording {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
        }
        .onChange(of: state) { _, newValue in
            if newValue == .recording {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            } else {
                isPulsing = false
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

#Preview {
    ContentView()
        .environmentObject(AppNavigationModel())
}
