import Foundation

public enum MeetingNoteParsing {
    public struct NoteMetadata: Equatable, Sendable {
        public var meetingTypeId: String?
        public var frontmatterLines: [String]

        public init(meetingTypeId: String?, frontmatterLines: [String]) {
            self.meetingTypeId = meetingTypeId
            self.frontmatterLines = frontmatterLines
        }
    }

    public struct SpeakerHeader: Equatable, Sendable {
        public var speakerId: Int
        public var detectedName: String?
        public var suffix: String

        public init(speakerId: Int, detectedName: String?, suffix: String) {
            self.speakerId = speakerId
            self.detectedName = detectedName
            self.suffix = suffix
        }
    }

    public enum TranscriptLine: Equatable, Sendable {
        case speakerHeader(SpeakerHeader)
        case screenContextHeader(label: String, windowTitle: String?, timestampStartSeconds: Double)
        case text(String)
    }

    public static func parseSpeakerIDs(fromTranscriptMarkdown markdown: String?) -> [Int] {
        guard let markdown else { return [] }

        var ids: Set<Int> = []
        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("Speaker ") else { continue }

            let afterPrefix = trimmed.dropFirst("Speaker ".count)
            let digits = afterPrefix.prefix { $0.isNumber }
            if let id = Int(digits) {
                ids.insert(id)
            }
        }

        return ids.sorted()
    }

    public static func rewriteSpeakerHeadingsForDisplay(
        transcriptMarkdown: String,
        speakerDisplayNames: [Int: String]
    ) -> String {
        let lines = transcriptMarkdown.split(separator: "\n", omittingEmptySubsequences: false)
        var out: [String] = []
        out.reserveCapacity(lines.count)

        for lineSub in lines {
            let line = String(lineSub)
            let leadingWhitespace = line.prefix { $0.isWhitespace }
            let remainder = line.dropFirst(leadingWhitespace.count)
            let trimmed = remainder.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("Speaker ") {
                let afterPrefix = trimmed.dropFirst("Speaker ".count)
                let digits = afterPrefix.prefix { $0.isNumber }
                if let id = Int(digits),
                   let name = speakerDisplayNames[id]?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !name.isEmpty,
                   let bracketRange = trimmed.range(of: " [") {
                    let suffix = String(trimmed[bracketRange.lowerBound...])
                    out.append(String(leadingWhitespace) + name + suffix)
                    continue
                }
            }
            out.append(line)
        }

        return out.joined(separator: "\n")
    }

    public static func parseTranscriptLines(_ transcript: String) -> [TranscriptLine] {
        let lines = transcript.split(separator: "\n", omittingEmptySubsequences: false)
        return lines.map { sub in
            let line = String(sub)
            if let header = parseSpeakerHeader(line) {
                return .speakerHeader(header)
            }
            if let header = parseScreenContextHeader(line) {
                return .screenContextHeader(
                    label: header.label,
                    windowTitle: header.windowTitle,
                    timestampStartSeconds: header.timestampStartSeconds
                )
            }
            return .text(line)
        }
    }

    public static func parseTranscriptTimelineEntries(fromTranscriptMarkdown markdown: String?) -> [TranscriptTimelineEntry] {
        guard let markdown else { return [] }

        let (_, body) = splitTranscriptHeaderAndBody(markdown)
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var entries: [TranscriptTimelineEntry] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]

            if let speakerHeader = parseSpeakerHeader(line) {
                let timestamp = parseTimestampRange(from: speakerHeader.suffix)
                let textLines = consumeTimelineBodyLines(from: lines, startingAt: index + 1)
                entries.append(
                    TranscriptTimelineEntry(
                        kind: .speakerSegment,
                        timestampStartSeconds: timestamp.start,
                        timestampEndSeconds: timestamp.end,
                        displayLabel: "Speaker \(speakerHeader.speakerId)",
                        text: textLines.joined(separator: "\n"),
                        speakerId: speakerHeader.speakerId
                    )
                )
                index += textLines.count + 1
                continue
            }

            if let screenContextHeader = parseScreenContextHeader(line) {
                let textLines = consumeTimelineBodyLines(from: lines, startingAt: index + 1)
                entries.append(
                    TranscriptTimelineEntry(
                        kind: .screenContext,
                        timestampStartSeconds: screenContextHeader.timestampStartSeconds,
                        displayLabel: screenContextHeader.label,
                        text: textLines.joined(separator: "\n"),
                        windowTitle: screenContextHeader.windowTitle
                    )
                )
                index += textLines.count + 1
                continue
            }

            index += 1
        }

        return entries.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    public static func splitTranscriptHeaderAndBody(_ transcript: String) -> (header: String, body: String) {
        let lines = transcript.split(separator: "\n", omittingEmptySubsequences: false)

        var firstHeaderIndex: Int?
        for (index, lineSub) in lines.enumerated() {
            let line = String(lineSub)
            if parseSpeakerHeader(line) != nil || parseScreenContextHeader(line) != nil {
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

    public static func containsSpeakerHeader(_ transcript: String) -> Bool {
        for lineSub in transcript.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(lineSub)
            if parseSpeakerHeader(line) != nil || parseScreenContextHeader(line) != nil {
                return true
            }
        }
        return false
    }

    public static func parseNoteMetadata(fromNoteMarkdown markdown: String?) -> NoteMetadata {
        guard let frontmatterLines = extractFrontmatterLines(fromNoteMarkdown: markdown) else {
            return NoteMetadata(meetingTypeId: nil, frontmatterLines: [])
        }

        return NoteMetadata(
            meetingTypeId: parseMeetingTypeID(fromFrontmatterLines: frontmatterLines),
            frontmatterLines: frontmatterLines
        )
    }

    public static func frontmatterValue(forKey key: String, inNoteMarkdown markdown: String?) -> String? {
        guard let frontmatterLines = extractFrontmatterLines(fromNoteMarkdown: markdown) else {
            return nil
        }

        return frontmatterValue(forKey: key, inFrontmatterLines: frontmatterLines)
    }

    public static func parseMeetingTypeID(fromNoteMarkdown markdown: String?) -> String? {
        guard let frontmatterLines = extractFrontmatterLines(fromNoteMarkdown: markdown) else {
            return nil
        }

        return parseMeetingTypeID(fromFrontmatterLines: frontmatterLines)
    }

    public static func extractFrontmatterLines(fromNoteMarkdown markdown: String?) -> [String]? {
        guard let markdown else { return nil }

        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count >= 3, lines.first == "---" else { return nil }

        guard let closingIndex = lines.dropFirst().firstIndex(of: "---"), closingIndex > 1 else {
            return nil
        }

        return Array(lines[1..<closingIndex]).map(String.init)
    }

    public static func parseAudioDurationSeconds(fromNoteMarkdown markdown: String?) -> TimeInterval? {
        guard let rawValue = frontmatterValue(forKey: "length", inNoteMarkdown: markdown) else {
            return nil
        }

        return parseDurationSeconds(fromFrontmatterValue: rawValue)
    }

    public static func summarizationSourceText(fromTranscriptMarkdown markdown: String) -> String {
        let timelineEntries = parseTranscriptTimelineEntries(fromTranscriptMarkdown: markdown)
        if !timelineEntries.isEmpty {
            return renderSummarizationTimeline(entries: timelineEntries)
        }

        let (_, body) = splitTranscriptHeaderAndBody(markdown)
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func linkedRelativePath(inNoteMarkdown markdown: String?, sectionHeading: String) -> String? {
        guard let markdown else { return nil }

        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let headingIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == sectionHeading }) else {
            return nil
        }

        for line in lines[(headingIndex + 1)...] {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }
            guard trimmed.hasPrefix("[["), trimmed.hasSuffix("]]"), trimmed.count > 4 else {
                return nil
            }

            let startIndex = trimmed.index(trimmed.startIndex, offsetBy: 2)
            let endIndex = trimmed.index(trimmed.endIndex, offsetBy: -2)
            return String(trimmed[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    public static func noteMayContainUserEdits(inNoteMarkdown markdown: String?) -> Bool {
        guard let markdown else { return false }

        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let contentLines: [String]
        if let frontmatter = extractFrontmatterLines(fromNoteMarkdown: markdown) {
            contentLines = Array(lines.dropFirst(frontmatter.count + 3))
        } else {
            contentLines = lines
        }

        enum Section: String {
            case none
            case summary = "## Summary"
            case decisions = "## Decisions"
            case actionItems = "## Action Items"
            case openQuestions = "## Open Questions"
            case keyPoints = "## Key Points"
            case audio = "## Audio"
            case transcript = "## Transcript"
        }

        var currentSection: Section = .none
        var summaryContentLineCount = 0

        for rawLine in contentLines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("# ") {
                if currentSection != .none {
                    return true
                }
                continue
            }

            if let section = Section(rawValue: line) {
                currentSection = section
                continue
            }

            switch currentSection {
            case .summary:
                summaryContentLineCount += 1
                if summaryContentLineCount > 1 {
                    return true
                }
            case .decisions, .openQuestions, .keyPoints:
                if !line.hasPrefix("- ") {
                    return true
                }
            case .actionItems:
                if !line.hasPrefix("- [ ] ") {
                    return true
                }
            case .audio, .transcript:
                if !(line.hasPrefix("[[") && line.hasSuffix("]]")) {
                    return true
                }
            case .none:
                return true
            }
        }

        return false
    }

    private static func parseSpeakerHeader(_ line: String) -> SpeakerHeader? {
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
        if afterDigitsTrimmed.hasPrefix("("),
           let closeIndex = afterDigitsTrimmed.firstIndex(of: ")") {
            let nameRange = afterDigitsTrimmed.index(after: afterDigitsTrimmed.startIndex)..<closeIndex
            let name = String(afterDigitsTrimmed[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                detectedName = name
            }
        }

        guard let bracketRange = trimmed.range(of: " [") else {
            return nil
        }

        let suffix = String(trimmed[bracketRange.lowerBound...])
        return SpeakerHeader(speakerId: speakerId, detectedName: detectedName, suffix: suffix)
    }

    private struct ScreenContextHeader: Equatable, Sendable {
        var label: String
        var windowTitle: String?
        var timestampStartSeconds: Double
    }

    private static func parseScreenContextHeader(_ line: String) -> ScreenContextHeader? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("Screen Context") else { return nil }
        guard let openingBracket = trimmed.lastIndex(of: "["), trimmed.hasSuffix("]") else {
            return nil
        }

        let prefix = trimmed[..<openingBracket].trimmingCharacters(in: .whitespacesAndNewlines)
        let timestampToken = trimmed[trimmed.index(after: openingBracket)..<trimmed.index(before: trimmed.endIndex)]
        guard let timestampStartSeconds = parseTimestampSeconds(String(timestampToken)) else {
            return nil
        }

        var windowTitle: String?
        if let openParen = prefix.firstIndex(of: "("), let closeParen = prefix.lastIndex(of: ")"), openParen < closeParen {
            let titleStart = prefix.index(after: openParen)
            let title = prefix[titleStart..<closeParen].trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                windowTitle = title
            }
        }

        return ScreenContextHeader(
            label: "Screen Context",
            windowTitle: windowTitle,
            timestampStartSeconds: timestampStartSeconds
        )
    }

    private static func consumeTimelineBodyLines(from lines: [String], startingAt index: Int) -> [String] {
        guard index < lines.count else { return [] }
        var bodyLines: [String] = []
        var currentIndex = index

        while currentIndex < lines.count {
            let line = lines[currentIndex]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                break
            }
            if parseSpeakerHeader(line) != nil || parseScreenContextHeader(line) != nil {
                break
            }
            bodyLines.append(trimmed)
            currentIndex += 1
        }

        return bodyLines
    }

    private static func parseTimestampRange(from suffix: String) -> (start: Double, end: Double?) {
        let trimmed = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else { return (0, nil) }
        let token = String(trimmed.dropFirst().dropLast())
        let components = token.components(separatedBy: " - ")
        let start = parseTimestampSeconds(components.first ?? "") ?? 0
        let end = components.count > 1 ? parseTimestampSeconds(components[1]) : nil
        return (start, end)
    }

    private static func parseTimestampSeconds(_ token: String) -> Double? {
        let parts = token.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 2:
            return Double((parts[0] * 60) + parts[1])
        case 3:
            return Double((parts[0] * 3600) + (parts[1] * 60) + parts[2])
        default:
            return nil
        }
    }

    private static func renderSummarizationTimeline(entries: [TranscriptTimelineEntry]) -> String {
        entries.compactMap { entry in
            let timestamp = formatSummarizationTimestamp(entry.timestampStartSeconds)
            let text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }

            switch entry.kind {
            case .speakerSegment:
                let speakerId = entry.speakerId ?? 0
                return "[\(timestamp)] Speaker \(speakerId): \(text)"
            case .screenContext:
                return "[\(timestamp)] Screen context - \(text)"
            }
        }
        .joined(separator: "\n")
    }

    private static func formatSummarizationTimestamp(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    private static func parseMeetingTypeID(fromFrontmatterLines frontmatterLines: [String]) -> String? {
        frontmatterValue(forKey: "meeting_type", inFrontmatterLines: frontmatterLines)
    }

    private static func frontmatterValue(forKey key: String, inFrontmatterLines frontmatterLines: [String]) -> String? {
        for line in frontmatterLines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("\(key):") else { continue }

            let prefix = "\(key):"
            let valueStart = trimmed.index(trimmed.startIndex, offsetBy: prefix.count)
            let value = trimmed[valueStart...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            return value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }

        return nil
    }

    private static func parseDurationSeconds(fromFrontmatterValue value: String) -> TimeInterval? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var totalMinutes = 0
        for component in trimmed.split(separator: " ") {
            let token = component.trimmingCharacters(in: .whitespacesAndNewlines)
            if token.hasSuffix("h"), let hours = Int(token.dropLast()) {
                totalMinutes += hours * 60
            } else if token.hasSuffix("m"), let minutes = Int(token.dropLast()) {
                totalMinutes += minutes
            }
        }

        guard totalMinutes > 0 else { return nil }
        return TimeInterval(totalMinutes * 60)
    }
}
