import AppKit
import Combine
import MinuteCore
import SwiftUI
import UniformTypeIdentifiers

struct PipelineContentView: View {
    @EnvironmentObject private var appState: AppNavigationModel
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
    @State private var dismissedStatusDrawerID: String?
    private let statusPresenter = PipelineStatusPresenter()

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
                                    .zIndex(0)

                                floatingControlBar
                                    .frame(maxWidth: 720)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: floatingBarHeight, alignment: .bottom)
                                    .padding(.bottom, isCompactLayout ? 12 : 22)
                                    .zIndex(2)

                                if let status = statusDrawerModel {
                                    StatusDrawerView(model: status, isCompact: isCompactLayout)
                                        .frame(maxWidth: 560)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.bottom, statusDrawerBottomPadding(isCompact: isCompactLayout))
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                        .animation(.easeInOut(duration: 0.2), value: statusDrawerModel != nil)
                                        .zIndex(3)
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
                syncDismissedStatusDrawer(with: newState)
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
            .onReceive(NotificationCenter.default.publisher(for: .minuteRecordingAlertShowPipeline)) { _ in
                notesModel.dismissOverlay()
            }
            .onChange(of: appState.mainContent) { _, mainContent in
                if mainContent == .pipeline {
                    model.workspaceDidBecomeVisible()
                }
            }
            .confirmationDialog(
                notesModel.reprocessConfirmationTitle,
                isPresented: reprocessConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Resummarize") {
                    notesModel.confirmPendingReprocess()
                }

                Button("Cancel", role: .cancel) {
                    notesModel.cancelPendingReprocess()
                }
            } message: {
                Text(notesModel.reprocessConfirmationMessage)
            }
            .alert(
                "Resummarization Failed",
                isPresented: reprocessErrorPresented
            ) {
                Button("OK", role: .cancel) {
                    notesModel.dismissReprocessError()
                }
            } message: {
                Text(notesModel.reprocessErrorMessage ?? "")
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
                reprocessTargetTypes: notesModel.selectedItem.map {
                    notesModel.availableReprocessTargetTypes(for: $0)
                } ?? [],
                canReprocess: (notesModel.selectedItem.map {
                    notesModel.reprocessAvailability(for: $0).canReprocess
                } ?? false) && !notesModel.isReprocessingMeeting,
                reprocessDisabledReason: notesModel.selectedItem.flatMap {
                    notesModel.reprocessDisabledReason(for: $0)
                },
                onSelectReprocessTarget: { targetTypeID in
                    guard let item = notesModel.selectedItem else { return }
                    notesModel.prepareReprocess(for: item, targetTypeID: targetTypeID)
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

    private var reprocessConfirmationPresented: Binding<Bool> {
        Binding(
            get: { notesModel.pendingReprocessSelection != nil },
            set: { isPresented in
                if !isPresented {
                    notesModel.cancelPendingReprocess()
                }
            }
        )
    }

    private var reprocessErrorPresented: Binding<Bool> {
        Binding(
            get: { notesModel.reprocessErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    notesModel.dismissReprocessError()
                }
            }
        )
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
        if model.captureState == .stopping {
            return "Stopping"
        }

        switch model.state {
        case .recording:
            return "Recording"
        case .processing, .writing, .importing:
            return model.currentStatusLabel
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
        if recordButtonState == .stopping {
            return .orange
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
        case .stopping:
            return .stopping
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
        case .stopping:
            return false
        }
    }

    private var statusDrawerModel: StatusDrawerModel? {
        guard let presentation = statusPresenter.presentation(
            for: PipelineStatusPresenter.Input(
                state: model.state,
                backgroundProcessingSnapshot: model.backgroundProcessingSnapshot,
                isFirstScreenInferenceDeferred: model.screenInferenceStatus?.isFirstInferenceDeferred == true,
                progress: model.progress,
                statusLabelOverride: model.statusLabelOverride,
                recoverableRecordings: model.recoverableRecordings,
                recordingWarningDetail: recordingWarningDetailText(),
                summarizationProgressDetail: model.summarizationProgressDetail
            ),
            dismissedStatusDrawerID: dismissedStatusDrawerID
        ) else {
            return nil
        }

        return StatusDrawerModel(
            title: presentation.title,
            detail: presentation.detail,
            progress: presentation.progress,
            showsActivity: presentation.showsActivity,
            isError: presentation.isError,
            actionTitle: presentation.primaryActionTitle,
            action: statusAction(for: presentation.primaryAction),
            secondaryActionTitle: presentation.secondaryActionTitle,
            secondaryAction: statusAction(for: presentation.secondaryAction),
            onClose: presentation.showsCloseButton ? { dismissCurrentStatusDrawer() } : nil
        )
    }

    private func statusAction(for action: PipelineStatusPresenter.Action?) -> (() -> Void)? {
        guard let action else { return nil }
        return {
            switch action {
            case .keepRecording:
                model.keepRecordingFromWarning()
            case .cancelBackgroundProcessing(let clearPending):
                model.cancelBackgroundProcessing(clearPending: clearPending)
            case .retryBackgroundProcessing:
                model.retryBackgroundProcessing()
            case .recoverRecording(let recording):
                model.recoverRecording(recording)
            case .discardRecoverableRecording(let recording):
                model.discardRecoverableRecording(recording)
            case .process:
                model.send(.process)
            case .revealInFinder(let noteURL):
                model.revealInFinder(noteURL)
            }
        }
    }

    private func recordingWarningDetailText() -> String? {
        var parts: [String] = []

        if let silenceMessage = model.activeSilenceWarningMessage {
            let countdown = model.activeSilenceWarningSecondsRemaining.map { " (\($0)s)" } ?? ""
            parts.append("\(silenceMessage)\(countdown)")
        }

        if let screenMessage = model.activeScreenContextAlertMessage {
            let countdown = model.activeScreenContextWarningSecondsRemaining.map { " (\($0)s)" } ?? ""
            parts.append("\(screenMessage)\(countdown)")
        }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " • ")
    }

    private func mainSessionBottomInset(isCompact: Bool) -> CGFloat {
        isCompact ? 88 : 104
    }

    private func statusDrawerBottomPadding(isCompact: Bool) -> CGFloat {
        let spacing: CGFloat = isCompact ? 6 : 10
        let bottomPadding: CGFloat = isCompact ? 12 : 22
        return bottomPadding + floatingBarHeight + spacing
    }

    private func dismissCurrentStatusDrawer() {
        guard let id = statusPresenter.dismissibleStatusDrawerID(for: model.state) else { return }
        dismissedStatusDrawerID = id
    }

    private func syncDismissedStatusDrawer(with state: MeetingPipelineState) {
        guard let dismissedStatusDrawerID else { return }
        if statusPresenter.dismissibleStatusDrawerID(for: state) != dismissedStatusDrawerID {
            self.dismissedStatusDrawerID = nil
        }
    }

    private func handleRecordButtonTap() {
        switch model.captureState {
        case .ready:
            performHaptic(.alignment)
            requestStartRecording()
        case .recording:
            performHaptic(.levelChange)
            model.send(.stopRecording)
        case .stopping:
            break
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
