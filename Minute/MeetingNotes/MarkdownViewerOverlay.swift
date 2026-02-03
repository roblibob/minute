import MarkdownUI
import SwiftUI

struct MarkdownViewerOverlay: View {
    var title: String
    var summaryContent: String?
    var transcriptContent: String?
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
            if isTranscriptionAvailable {
                Button(action: toggleTab) {
                    Text(toggleTitle)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help(toggleHelpText)
            }

            if let onOpenInObsidian {
                Button(action: onOpenInObsidian) {
                    Image(systemName: "arrow.up.right.square")
                }
                .buttonStyle(.borderless)
                .controlSize(.large)
                .help("Open in Obsidian")
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .accessibilityLabel("Close note preview")
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

    private var toggleTitle: String {
        selectedTab == .summary ? "Transcription" : "Summary"
    }

    private var toggleHelpText: String {
        selectedTab == .summary ? "Show transcription" : "Show summary"
    }

    private func toggleTab() {
        let next: MeetingNotePreviewTab = selectedTab == .summary ? .transcription : .summary
        DispatchQueue.main.async {
            onSelectTab(next)
        }
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

#Preview {
    MarkdownViewerOverlay(
        title: "Meeting Preview",
        summaryContent: "# Title\n\nSome **markdown** content.",
        transcriptContent: "# Transcript\n\nHello world.",
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
        onOpenInObsidian: {}
    )
}

private extension MarkdownViewerOverlay {
    func decoratedContent(_ content: String) -> String {
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

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard let colonIndex = trimmed.firstIndex(of: ":") else { continue }

            let key = trimmed[..<colonIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawValue = trimmed[trimmed.index(after: colonIndex)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let value = trimMatchingQuotes(rawValue)

            entries.append((String(key), String(value)))
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
