import AppKit
import Combine
import MinuteCore
import SwiftUI
import UniformTypeIdentifiers

struct PipelineContentView: View {
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
    @State private var sessionDropErrorMessage: String?
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
                    Group {
                        if notesModel.isOverlayPresented {
                            meetingOverlay
                                .safeAreaInset(edge: .top, spacing: 0) {
                                    Color.clear
                                        .frame(height: 16)
                                }
                        } else {
                            ZStack(alignment: .bottom) {
                                mainSession(bottomInset: mainSessionBottomInset(isCompact: isCompactLayout))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .transaction { transaction in
                                        transaction.animation = nil
                                    }

                                floatingControlBar
                                    .frame(maxWidth: 720)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: floatingBarHeight, alignment: .bottom)
                                    .padding(.bottom, isCompactLayout ? 12 : 22)

                                if let status = statusDrawerModel {
                                    StatusDrawerView(model: status, isCompact: isCompactLayout)
                                        .frame(maxWidth: 560)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.bottom, statusDrawerBottomPadding(isCompact: isCompactLayout))
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                        .animation(.easeInOut(duration: 0.2), value: statusDrawerModel != nil)
                                }
                            }
                        }
                    }
                }
                .background(MinuteTheme.windowBackground)
                .toolbar(removing: .sidebarToggle)
                .navigationSplitViewStyle(.balanced)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                guard !notesModel.isOverlayPresented else { return false }
                return handleDrop(providers)
            }
            .fileImporter(isPresented: $isImportingFile, allowedContentTypes: SessionMediaValidation.importableContentTypes) { result in
                switch result {
                case .success(let url):
                    importFile(url)
                case .failure:
                    break
                }
            }
            .onChange(of: screenContextEnabled) { _, newValue in
                handleScreenContextSettingChange(newValue)
            }
            .onReceive(NotificationCenter.default.publisher(for: .minuteMicActivityStartRecording)) { _ in
                handleNotificationStartRecording()
            }
        }
    }

    private func mainSession(bottomInset: CGFloat) -> some View {
        MainSessionView(
            model: model,
            notesModel: notesModel,
            bottomInset: bottomInset,
            screenContextEnabled: screenContextEnabled,
            isDropTargeted: isDropTargeted,
            dropErrorMessage: sessionDropErrorMessage,
            onUploadTap: { isImportingFile = true }
        )
    }

    @ViewBuilder
    private var meetingOverlay: some View {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear
                    .frame(height: 16)
            }
            .background(MinuteTheme.windowBackground)
        }
    }

    private var floatingControlBar: some View {
        FloatingControlBar(
            recordState: recordButtonState,
            recordEnabled: recordButtonEnabled,
            recordingStartedAt: recordingStartedAt,
            showsCancel: recordButtonState == .recording,
            recordFocus: $recordButtonFocused,
            onRecordTap: handleRecordButtonTap,
            onCancelTap: handleCancelSessionTap
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

                guard let url else { return }

                guard SessionMediaValidation.isSupportedMediaURL(url) else {
                    Task { @MainActor in
                        showSessionDropError("Unsupported file type. Drop an audio or video file.")
                    }
                    return
                }

                Task { @MainActor in importFile(url) }
            }
            return true
        }

        return false
    }

    private func showSessionDropError(_ message: String) {
        sessionDropErrorMessage = message

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if sessionDropErrorMessage == message {
                sessionDropErrorMessage = nil
            }
        }
    }

    private func importFile(_ url: URL) {
        model.send(.importFile(url))
    }

    private var recordingStartedAt: Date? {
        guard case .recording(let session) = model.state else { return nil }
        return session.startedAt
    }

    private var floatingStatusLabel: String {
        switch model.state {
        case .recording:
            return "Recording"
        case .processing, .writing, .importing:
            return model.state.statusLabel
        case .recorded:
            return "Ready to Process"
        case .failed:
            return "Failed"
        default:
            return "Ready"
        }
    }

    private var statusIndicatorColor: Color {
        if recordButtonState == .recording {
            return .red
        }
        if recordButtonEnabled {
            return .green
        }
        return .gray
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

    private func mainSessionBottomInset(isCompact: Bool) -> CGFloat {
        isCompact ? 88 : 104
    }

    private func statusDrawerBottomPadding(isCompact: Bool) -> CGFloat {
        let spacing: CGFloat = isCompact ? 6 : 10
        let bottomPadding: CGFloat = isCompact ? 12 : 22
        return bottomPadding + floatingBarHeight + spacing
    }

    private func handleRecordButtonTap() {
        switch model.captureState {
        case .ready:
            performHaptic(.alignment)
            requestStartRecording()
        case .recording:
            performHaptic(.levelChange)
            model.send(.stopRecording)
        }
    }

    private func handleCancelSessionTap() {
        performHaptic(.alignment)
        model.send(.cancelRecording)
    }

    private func performHaptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    private func handleNotificationStartRecording() {
        if model.captureState == .ready {
            handleRecordButtonTap()
        }
    }

    private func requestStartRecording() {
        model.send(.startRecording)
    }

    private func handleScreenContextSettingChange(_ enabled: Bool) {
        if !enabled {
            model.setScreenCaptureSelection(nil)
        }
        model.setScreenCaptureEnabled(enabled)
    }
}
