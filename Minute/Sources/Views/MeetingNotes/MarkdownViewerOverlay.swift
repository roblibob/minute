import AppKit
import MarkdownUI
import SwiftUI

struct MarkdownViewerOverlay: View {
    struct SpeakerEditorConfig {
        var speakerIDs: [Int]
        var speakerName: (Int) -> String
        var setSpeakerName: (Int, String) -> Void
        var knownSpeakerProfileNames: [String]
        var save: () -> Void
        var isSaving: Bool
        var errorMessage: String?
        var enrollmentErrorMessage: String?
        var enrollKnownSpeaker: (Int) -> Void
        var isEnrollingKnownSpeaker: (Int) -> Bool
        var isKnownSpeaker: (Int) -> Bool
        var knownSpeakerName: (Int) -> String?
        var isRewritingTranscriptHeadings: Bool
        var rewriteErrorMessage: String?
    }

    var title: String
    var summaryContent: String?
    var transcriptContent: String?
    var rawTranscriptContent: String? = nil
    var isLoadingSummary: Bool
    var isLoadingTranscript: Bool
    var summaryErrorMessage: String?
    var transcriptErrorMessage: String?
    var renderSummaryPlainText: Bool
    var renderTranscriptPlainText: Bool
    var hasTranscript: Bool
    var selectedTab: MeetingNotePreviewTab
    var onSelectTab: (MeetingNotePreviewTab) -> Void
    var onClose: () -> Void
    var onRetry: (MeetingNotePreviewTab) -> Void
    var onOpenInObsidian: (() -> Void)?
    var onOpenSummaryInObsidian: (() -> Void)?
    var onOpenTranscriptInObsidian: (() -> Void)?
    var onRevealInFinder: (() -> Void)?
    var onDelete: (() -> Void)?
    var speakerEditor: SpeakerEditorConfig? = nil
    private let scrollBottomInset: CGFloat = 160

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
            bodyContent
        }
        .onChange(of: isTranscriptionAvailable) { _, newValue in
            if !newValue, selectedTab == .transcription {
                DispatchQueue.main.async {
                    onSelectTab(.summary)
                }
            }
        }
        .onExitCommand(perform: onClose)
    }

    private var header: some View {
        HStack {
            Text(title.isEmpty ? "Meeting Note" : title)
                .font(.system(size: 18, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(Color.minuteTextPrimary)
                .lineLimit(1)

            Spacer()
            toolbarContent
        }
        .padding(16)
    }
 
    private var toolbarContent: some View {
        HStack(spacing: 12) {
            if let onOpenInObsidian {
                Button(action: onOpenInObsidian) {
                    Label("Open in Obsidian", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("Open in Obsidian")
            }

            Menu {
                Button {
                    onSelectTab(.summary)
                } label: {
                    Label("View Summary", systemImage: "doc.text")
                }
                .disabled(selectedTab == .summary)

                Button {
                    onSelectTab(.transcription)
                } label: {
                    Label("View Transcript", systemImage: "text.bubble")
                }
                .disabled(selectedTab == .transcription || !hasTranscript)

                Divider()

                Button {
                    onOpenSummaryInObsidian?()
                } label: {
                    Label("Open Summary in Obsidian", systemImage: "arrow.up.right.square")
                }

                Button {
                    onOpenTranscriptInObsidian?()
                } label: {
                    Label("Open Transcript in Obsidian", systemImage: "arrow.up.right.square")
                }
                .disabled(!hasTranscript)

                Button {
                    onRevealInFinder?()
                } label: {
                    Label("Reveal in Finder", systemImage: "finder")
                }

                Divider()

                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.minuteTextPrimary)
                    .frame(width: 28, height: 28, alignment: .center)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("More")
            .accessibilityLabel("More")

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .accessibilityLabel("Close note preview")
        }
    }

    private func speakersPopover(editor: SpeakerEditorConfig, showsTitle: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsTitle {
                Text("Speakers")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.minuteTextPrimary)
            }

            if let message = editor.errorMessage {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }

            if let message = editor.rewriteErrorMessage {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }

            if let message = editor.enrollmentErrorMessage {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(editor.speakerIDs, id: \.self) { speakerId in
                    let showKnownSpeakerCheckmark: Bool = {
                        guard editor.isKnownSpeaker(speakerId) else { return false }
                        guard let knownName = editor.knownSpeakerName(speakerId) else { return true }

                        let draftTrimmed = editor.speakerName(speakerId)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        let knownTrimmed = knownName
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if draftTrimmed.isEmpty { return true }
                        return draftTrimmed == knownTrimmed
                    }()

                    HStack(spacing: 8) {
                        Text("Speaker \(speakerId)")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 90, alignment: .leading)

                        AutocompleteComboBox(
                            text: Binding(
                                get: { editor.speakerName(speakerId) },
                                set: { editor.setSpeakerName(speakerId, $0) }
                            ),
                            items: editor.knownSpeakerProfileNames,
                            placeholder: "Name"
                        )
                        .frame(width: 220)

                        if editor.isEnrollingKnownSpeaker(speakerId) {
                            ProgressView()
                                .controlSize(.small)
                        } else if showKnownSpeakerCheckmark {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.green)
                                .frame(width: 28, height: 28)
                                .help(editor.knownSpeakerName(speakerId).map { "Known Speaker: \($0)" } ?? "Known Speaker")
                        } else {
                            Button {
                                editor.enrollKnownSpeaker(speakerId)
                            } label: {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.borderless)
                            .help("Save as Known Speaker…")
                            .disabled(editor.isSaving || editor.isRewritingTranscriptHeadings)
                        }
                    }
                }
            }

            HStack {
                Spacer()

                if editor.isSaving || editor.isRewritingTranscriptHeadings {
                    ProgressView()
                        .controlSize(.small)
                }

                Button("Save") {
                    editor.save()
                }
                .disabled(editor.isSaving || editor.isRewritingTranscriptHeadings)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var isTranscriptionAvailable: Bool {
        if hasTranscript {
            return true
        }
        if isLoadingTranscript {
            return true
        }
        if transcriptContent != nil {
            return true
        }
        if transcriptErrorMessage != nil {
            return true
        }
        return false
    }

    @ViewBuilder
    private var bodyContent: some View {
        if activeIsLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text(activeLoadingLabel)
                    .minuteCaption()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        } else if let errorMessage = activeErrorMessage {
            VStack(spacing: 12) {
                Text(errorMessage)
                    .foregroundStyle(.red)

                Button("Retry") {
                    onRetry(selectedTab)
                }
                .minuteStandardButtonStyle()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        } else if selectedTab == .transcription,
                  !activeRenderPlainText,
                  let editor = speakerEditor,
                  let transcript = (rawTranscriptContent ?? transcriptContent),
                  TranscriptLineParser.containsSpeakerHeader(transcript) {
            InteractiveTranscriptView(
                transcript: transcript,
                speakerName: editor.speakerName,
                setSpeakerName: editor.setSpeakerName,
                knownProfileNames: editor.knownSpeakerProfileNames,
                enrollKnownSpeaker: editor.enrollKnownSpeaker,
                saveSpeakerNames: editor.save
            )
            .font(.callout)
            .foregroundStyle(Color.minuteTextPrimary)
            .padding(20)
        } else if let content = activeContent {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if activeRenderPlainText {
                        Text(content)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    } else {
                        Markdown(decoratedContent(content))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer()
                        .frame(height: scrollBottomInset)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.callout)
            .foregroundStyle(Color.minuteTextPrimary)
            .padding(20)
        } else {
            Text(activeEmptyLabel)
                .minuteCaption()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
        }
    }

    private var activeContent: String? {
        switch selectedTab {
        case .summary:
            return summaryContent
        case .transcription:
            return transcriptContent
        }
    }

    private var activeIsLoading: Bool {
        switch selectedTab {
        case .summary:
            return isLoadingSummary
        case .transcription:
            return isLoadingTranscript
        }
    }

    private var activeErrorMessage: String? {
        switch selectedTab {
        case .summary:
            return summaryErrorMessage
        case .transcription:
            return transcriptErrorMessage
        }
    }

    private var activeRenderPlainText: Bool {
        switch selectedTab {
        case .summary:
            return renderSummaryPlainText
        case .transcription:
            return renderTranscriptPlainText
        }
    }

    private var activeLoadingLabel: String {
        switch selectedTab {
        case .summary:
            return "Loading note…"
        case .transcription:
            return "Loading transcription…"
        }
    }

    private var activeEmptyLabel: String {
        switch selectedTab {
        case .summary:
            return "No summary available."
        case .transcription:
            return "No transcription available."
        }
    }
}

// MARK: - Autocomplete / Interactive Transcript

private struct AutocompleteComboBox: NSViewRepresentable {
    @Binding var text: String
    var items: [String]
    var placeholder: String = ""
    var onCommit: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCommit: onCommit, onCancel: onCancel)
    }

    func makeNSView(context: Context) -> NSComboBox {
        let comboBox = NSComboBox(frame: .zero)
        comboBox.usesDataSource = false
        comboBox.completes = true
        comboBox.isEditable = true
        comboBox.isBordered = true
        comboBox.hasVerticalScroller = true
        comboBox.numberOfVisibleItems = 10
        comboBox.placeholderString = placeholder
        comboBox.delegate = context.coordinator
        comboBox.removeAllItems()
        comboBox.addItems(withObjectValues: items)
        comboBox.stringValue = text
        return comboBox
    }

    func updateNSView(_ nsView: NSComboBox, context: Context) {
        context.coordinator.isApplyingProgrammaticUpdate = true
        defer { context.coordinator.isApplyingProgrammaticUpdate = false }

        if context.coordinator.items != items {
            context.coordinator.items = items
            nsView.removeAllItems()
            nsView.addItems(withObjectValues: items)
        }

        // Avoid clobbering the user's selection/caret while they are actively editing.
        // Syncing `stringValue` during editing can cause the whole text to become selected,
        // so the next keystroke replaces the entire value.
        guard nsView.currentEditor() == nil else { return }
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSComboBoxDelegate {
        private var text: Binding<String>
        private var onCommit: (() -> Void)?
        private var onCancel: (() -> Void)?
        fileprivate var items: [String] = []
        fileprivate var isApplyingProgrammaticUpdate: Bool = false

        init(text: Binding<String>, onCommit: (() -> Void)?, onCancel: (() -> Void)?) {
            self.text = text
            self.onCommit = onCommit
            self.onCancel = onCancel
        }

        private func publishTextChange(_ value: String) {
            // NSComboBox delegate callbacks can occur during SwiftUI view updates.
            // Deferring avoids "Publishing changes from within view updates" warnings.
            DispatchQueue.main.async { [text] in
                text.wrappedValue = value
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                onCommit?()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                onCancel?()
                return true
            }
            return false
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            guard !isApplyingProgrammaticUpdate else { return }
            publishTextChange(comboBox.stringValue)
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let comboBox = obj.object as? NSComboBox else { return }
            guard !isApplyingProgrammaticUpdate else { return }
            publishTextChange(comboBox.stringValue)

            // If completion selected the full string, collapse to a caret at the end
            // so continued typing appends rather than replacing the whole name.
            DispatchQueue.main.async {
                guard let editor = comboBox.currentEditor() as? NSTextView else { return }
                let fullLength = (editor.string as NSString).length
                let selected = editor.selectedRange()
                guard fullLength > 0, selected.length == fullLength else { return }
                editor.setSelectedRange(NSRange(location: fullLength, length: 0))
            }
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            guard let comboBox = obj.object as? NSComboBox else { return }
            guard !isApplyingProgrammaticUpdate else { return }
            publishTextChange(comboBox.stringValue)
        }
    }
}

private struct InteractiveTranscriptView: View {
    let transcript: String
    let speakerName: (Int) -> String
    let setSpeakerName: (Int, String) -> Void
    let knownProfileNames: [String]
    let enrollKnownSpeaker: (Int) -> Void
    let saveSpeakerNames: () -> Void

    var body: some View {
        let (header, body) = TranscriptLineParser.splitHeaderAndBody(transcript)
        let lines = TranscriptLineParser.parse(body)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                if !header.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Markdown(Frontmatter.decorateContent(header))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 12)
                }

                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    switch line {
                    case .speakerHeader(let header):
                        SpeakerHeaderRow(
                            header: header,
                            currentDisplayName: {
                                let trimmed = speakerName(header.speakerId)
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                return trimmed.isEmpty ? nil : trimmed
                            }(),
                            knownProfileNames: knownProfileNames,
                            onPickName: { picked in
                                setSpeakerName(header.speakerId, picked)
                            },
                            onUseDetectedName: {
                                if let detected = header.detectedName {
                                    setSpeakerName(header.speakerId, detected)
                                }
                            },
                            onEnrollKnownSpeaker: {
                                enrollKnownSpeaker(header.speakerId)
                            },
                            onSaveSpeakerNames: {
                                saveSpeakerNames()
                            }
                        )

                    case .text(let text):
                        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Spacer().frame(height: 2)
                        } else {
                            Text(text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                }

                Spacer().frame(height: 160)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private enum TranscriptLine: Equatable {
    case speakerHeader(TranscriptSpeakerHeader)
    case text(String)
}

private struct TranscriptSpeakerHeader: Equatable {
    var speakerId: Int
    var detectedName: String?
    var suffix: String
}

private enum TranscriptLineParser {
    /// Deterministic parser for speaker header lines.
    ///
    /// Supported formats (examples):
    /// - `Speaker 1 (Einar) [00:00 - 00:43] ...`
    /// - `Speaker 3 [01:04 - 01:12] ...`
    ///
    /// Parsing strategy:
    /// - Only recognizes lines whose trimmed prefix starts with `Speaker <digits>`
    /// - Captures optional `(Name)` that appears immediately after the id
    /// - Captures the suffix starting at the first ` [` (bracketed time range + trailing text)
    static func parse(_ transcript: String) -> [TranscriptLine] {
        let lines = transcript.split(separator: "\n", omittingEmptySubsequences: false)
        return lines.map { sub in
            let line = String(sub)
            if let header = parseSpeakerHeader(line) {
                return .speakerHeader(header)
            }
            return .text(line)
        }
    }

    static func splitHeaderAndBody(_ transcript: String) -> (header: String, body: String) {
        let lines = transcript.split(separator: "\n", omittingEmptySubsequences: false)

        var firstHeaderIndex: Int?
        for (index, lineSub) in lines.enumerated() {
            if parseSpeakerHeader(String(lineSub)) != nil {
                firstHeaderIndex = index
                break
            }
        }

        guard let firstHeaderIndex else {
            return (header: transcript, body: "")
        }

        let headerLines = lines.prefix(firstHeaderIndex)
        let bodyLines = lines.suffix(from: firstHeaderIndex)

        return (
            header: headerLines.joined(separator: "\n"),
            body: bodyLines.joined(separator: "\n")
        )
    }

    static func containsSpeakerHeader(_ transcript: String) -> Bool {
        for lineSub in transcript.split(separator: "\n", omittingEmptySubsequences: false) {
            if parseSpeakerHeader(String(lineSub)) != nil {
                return true
            }
        }
        return false
    }

    private static func parseSpeakerHeader(_ line: String) -> TranscriptSpeakerHeader? {
        let leadingWhitespace = line.prefix { $0.isWhitespace }
        let remainder = line.dropFirst(leadingWhitespace.count)
        let trimmed = remainder.trimmingCharacters(in: .whitespaces)

        guard trimmed.hasPrefix("Speaker ") else { return nil }

        let afterPrefix = trimmed.dropFirst("Speaker ".count)
        let digits = afterPrefix.prefix { $0.isNumber }
        guard let speakerId = Int(digits) else { return nil }

        let afterDigits = afterPrefix.dropFirst(digits.count)
        var detectedName: String?

        let afterDigitsTrimmed = afterDigits.trimmingCharacters(in: .whitespaces)
        if afterDigitsTrimmed.hasPrefix("(") {
            if let closeIndex = afterDigitsTrimmed.firstIndex(of: ")") {
                let nameRange = afterDigitsTrimmed.index(after: afterDigitsTrimmed.startIndex)..<closeIndex
                let name = String(afterDigitsTrimmed[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    detectedName = name
                }
            }
        }

        guard let bracketRange = trimmed.range(of: " [") else {
            // No canonical time bracket means we treat it as a normal line to avoid false positives.
            return nil
        }

        let suffix = String(trimmed[bracketRange.lowerBound...])
        return TranscriptSpeakerHeader(speakerId: speakerId, detectedName: detectedName, suffix: suffix)
    }
}

private struct SpeakerHeaderRow: View {
    let header: TranscriptSpeakerHeader
    let currentDisplayName: String?
    let knownProfileNames: [String]
    let onPickName: (String) -> Void
    let onUseDetectedName: () -> Void
    let onEnrollKnownSpeaker: () -> Void
    let onSaveSpeakerNames: () -> Void

    @State private var isPopoverPresented: Bool = false
    @State private var draftName: String = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button {
                draftName = currentDisplayName ?? header.detectedName ?? ""
                isPopoverPresented = true
            } label: {
                Text(currentDisplayName ?? "Speaker \(header.speakerId)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.link)
            .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Assign profile")
                        .font(.headline)

                    AutocompleteComboBox(
                        text: Binding(
                            get: { draftName },
                            set: { newValue in
                                draftName = newValue
                                onPickName(newValue)
                            }
                        ),
                        items: knownProfileNames,
                        placeholder: "Known speaker name",
                        onCommit: {
                            let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else {
                                isPopoverPresented = false
                                return
                            }

                            // Normalize and apply, then enroll will create-or-append.
                            if trimmed != draftName {
                                draftName = trimmed
                                onPickName(trimmed)
                            }
                            onEnrollKnownSpeaker()
                            onSaveSpeakerNames()
                            isPopoverPresented = false
                        },
                        onCancel: {
                            isPopoverPresented = false
                        }
                    )
                    .frame(width: 280)

                    if let detected = header.detectedName, !detected.isEmpty {
                        Button("Use \"\(detected)\"") {
                            draftName = detected
                            onPickName(detected)
                            onUseDetectedName()
                        }
                    }

                    Text("Press Enter to save this speaker profile.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
            }

            Text(header.suffix)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    MarkdownViewerOverlay(
        title: "Meeting Preview",
        summaryContent: "# Title\n\nSome **markdown** content.",
        transcriptContent: "# Transcript\n\nHello world.",
        rawTranscriptContent: "# Transcript\n\nHello world.",
        isLoadingSummary: false,
        isLoadingTranscript: false,
        summaryErrorMessage: nil,
        transcriptErrorMessage: nil,
        renderSummaryPlainText: false,
        renderTranscriptPlainText: false,
        hasTranscript: true,
        selectedTab: .summary,
        onSelectTab: { _ in },
        onClose: {},
        onRetry: { _ in },
        onOpenInObsidian: {},
        onOpenSummaryInObsidian: {},
        onOpenTranscriptInObsidian: {},
        onRevealInFinder: {},
        onDelete: {}
    )
}

private extension MarkdownViewerOverlay {
    func decoratedContent(_ content: String) -> String {
        Frontmatter.decorateContent(content)
    }
}

private extension Frontmatter {
    static func decorateContent(_ content: String) -> String {
        guard let frontmatter = Frontmatter.parse(from: content) else {
            return content
        }

        let properties = frontmatter.propertiesMarkdown
        let body = frontmatter.body.trimmingCharacters(in: .whitespacesAndNewlines)

        if body.isEmpty {
            return properties
        }

        return "\(properties)\n\n\(body)"
    }
}

private struct Frontmatter {
    let propertiesMarkdown: String
    let body: String

    static func parse(from content: String) -> Frontmatter? {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        guard let first = lines.first,
              first.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else {
            return nil
        }

        var closingIndex: Int?
        for index in 1..<lines.count {
            if lines[index].trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                closingIndex = index
                break
            }
        }

        guard let closingIndex else { return nil }

        let frontmatterLines = lines[1..<closingIndex]
        let bodyLines = lines[(closingIndex + 1)...]
        let entries = parseEntries(from: frontmatterLines)

        guard !entries.isEmpty else { return nil }

        let propertiesMarkdown = renderProperties(entries)
        let body = bodyLines.joined(separator: "\n")
        return Frontmatter(propertiesMarkdown: propertiesMarkdown, body: body)
    }

    private static func parseEntries(from lines: ArraySlice<Substring>) -> [(String, String)] {
        var entries: [(String, String)] = []
        var index = lines.startIndex

        func isTopLevelLine(_ line: Substring) -> Bool {
            guard let first = line.first else { return false }
            return first != " " && first != "\t"
        }

        while index < lines.endIndex {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                index = lines.index(after: index)
                continue
            }

            guard isTopLevelLine(line),
                  let colonIndex = trimmed.firstIndex(of: ":") else {
                index = lines.index(after: index)
                continue
            }

            let key = trimmed[..<colonIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawValue = trimmed[trimmed.index(after: colonIndex)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !rawValue.isEmpty {
                entries.append((String(key), unescapeYAMLScalar(trimMatchingQuotes(String(rawValue)))))
                index = lines.index(after: index)
                continue
            }

            var collectedList: [String] = []
            var collectedMap: [(String, String)] = []
            var lookahead = lines.index(after: index)

            while lookahead < lines.endIndex {
                let nextLine = lines[lookahead]
                let nextTrimmed = nextLine.trimmingCharacters(in: .whitespacesAndNewlines)

                if nextTrimmed.isEmpty || nextTrimmed.hasPrefix("#") {
                    lookahead = lines.index(after: lookahead)
                    continue
                }

                if isTopLevelLine(nextLine) {
                    break
                }

                let nextContent = nextTrimmed
                if nextContent.hasPrefix("-") {
                    let valuePart = nextContent.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                    let scalar = unescapeYAMLScalar(trimMatchingQuotes(String(valuePart)))
                    if !scalar.isEmpty {
                        collectedList.append(scalar)
                    }
                } else if let innerColon = nextContent.firstIndex(of: ":") {
                    let mapKey = nextContent[..<innerColon].trimmingCharacters(in: .whitespacesAndNewlines)
                    let mapValue = nextContent[nextContent.index(after: innerColon)...]
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanKey = unescapeYAMLScalar(trimMatchingQuotes(String(mapKey)))
                    let cleanValue = unescapeYAMLScalar(trimMatchingQuotes(String(mapValue)))
                    if !cleanKey.isEmpty {
                        collectedMap.append((cleanKey, cleanValue))
                    }
                }

                lookahead = lines.index(after: lookahead)
            }

            if !collectedList.isEmpty {
                entries.append((String(key), collectedList.joined(separator: ", ")))
            } else if !collectedMap.isEmpty {
                let joined = collectedMap
                    .map { "\($0.0): \($0.1)" }
                    .joined(separator: ", ")
                entries.append((String(key), joined))
            } else {
                entries.append((String(key), ""))
            }

            index = lookahead
        }

        return entries
    }

    private static func trimMatchingQuotes(_ value: String) -> String {
        guard value.count >= 2,
              let first = value.first,
              let last = value.last,
              (first == "\"" && last == "\"") || (first == "'" && last == "'")
        else {
            return value
        }

        return String(value.dropFirst().dropLast())
    }

    private static func unescapeYAMLScalar(_ value: String) -> String {
        guard value.contains("\\") else { return value }

        var result = ""
        result.reserveCapacity(value.count)

        var index = value.startIndex
        while index < value.endIndex {
            let ch = value[index]
            if ch == "\\", let nextIndex = value.index(index, offsetBy: 1, limitedBy: value.endIndex), nextIndex < value.endIndex {
                let next = value[nextIndex]
                switch next {
                case "n": result.append("\n")
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                default: result.append(next)
                }
                index = value.index(after: nextIndex)
                continue
            }
            result.append(ch)
            index = value.index(after: index)
        }

        return result
    }

    private static func renderProperties(_ entries: [(String, String)]) -> String {
        var lines: [String] = [
            "## Properties",
            "| Key | Value |",
            "| --- | --- |"
        ]

        for (key, value) in entries {
            let safeKey = escapePipes(in: key)
            let safeValue = escapePipes(in: value)
            lines.append("| \(safeKey) | \(safeValue) |")
        }

        return lines.joined(separator: "\n")
    }

    private static func escapePipes(in value: String) -> String {
        value.replacingOccurrences(of: "|", with: "\\|")
    }
}
