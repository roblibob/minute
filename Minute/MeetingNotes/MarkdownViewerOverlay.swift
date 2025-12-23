import AppKit
import MarkdownUI
import SwiftUI

struct MarkdownViewerOverlay: View {
    var title: String
    var content: String?
    var isLoading: Bool
    var errorMessage: String?
    var renderPlainText: Bool
    var onClose: () -> Void
    var onRetry: () -> Void
    var onOpenInObsidian: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider()
                bodyContent
            }
            .frame(maxWidth: 860, maxHeight: 620)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(nsColor: NSColor.windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 12)
            .padding(24)
        }
        .onExitCommand(perform: onClose)
        .transition(.opacity)
    }

    private var header: some View {
        HStack {
            Text(title.isEmpty ? "Meeting Note" : title)
                .font(.title3.bold())
                .lineLimit(1)

            Spacer()

            if let onOpenInObsidian {
                Button("Open in Obsidian") {
                    onOpenInObsidian()
                }
                .minuteStandardButtonStyle()
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: NSColor.controlBackgroundColor))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close note preview")
        }
        .padding(16)
    }

    @ViewBuilder
    private var bodyContent: some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading note…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)

                Button("Retry") {
                    onRetry()
                }
                .minuteStandardButtonStyle()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        } else if let content {
            ScrollView {
                if renderPlainText {
                    Text(content)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                } else {
                    Markdown(decoratedContent(content))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .font(.callout)
            .padding(20)
        } else {
            Text("No content available.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
        }
    }
}

#Preview {
    MarkdownViewerOverlay(
        title: "Meeting Preview",
        content: "# Title\n\nSome **markdown** content.",
        isLoading: false,
        errorMessage: nil,
        renderPlainText: false,
        onClose: {},
        onRetry: {},
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
