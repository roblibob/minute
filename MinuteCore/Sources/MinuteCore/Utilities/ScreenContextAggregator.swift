import Foundation

public enum ScreenContextAggregator {
    public static func summarize(snapshots: [ScreenContextSnapshot]) -> ScreenContextSummary {
        var agendaItems: [String] = []
        var participantNames: [String] = []
        var sharedArtifacts: [String] = []
        var keyHeadings: [String] = []
        var notes: [String] = []
        var participantCount: Int?

        for snapshot in snapshots {
            let lines = normalizeLines(snapshot.extractedLines)

            if let count = parseParticipantCount(from: lines) {
                if let current = participantCount {
                    participantCount = max(current, count)
                } else {
                    participantCount = count
                }
            }

            let agenda = extractAgendaItems(from: lines)
            appendUnique(agenda, to: &agendaItems, limit: 10)

            let participants = extractParticipantNames(from: lines)
            appendUnique(participants, to: &participantNames, limit: 12)

            let artifacts = extractSharedArtifacts(from: lines)
            appendUnique(artifacts, to: &sharedArtifacts, limit: 10)

            let headings = extractHeadings(from: lines)
            appendUnique(headings, to: &keyHeadings, limit: 10)

            let extraNotes = extractNotes(from: lines)
            appendUnique(extraNotes, to: &notes, limit: 8)
        }

        return ScreenContextSummary(
            agendaItems: agendaItems,
            participantCount: participantCount,
            participantNames: participantNames,
            sharedArtifacts: sharedArtifacts,
            keyHeadings: keyHeadings,
            notes: notes
        )
    }
}

private extension ScreenContextAggregator {
    static func normalizeLines(_ lines: [String]) -> [String] {
        lines.compactMap { raw in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count > 1 else { return nil }
            let normalized = trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            let redacted = ScreenContextRedactor.redact(normalized)
            return redacted.isEmpty ? nil : redacted
        }
    }

    static func parseParticipantCount(from lines: [String]) -> Int? {
        for line in lines {
            if let count = parseCount(from: line) {
                return count
            }
        }
        return nil
    }

    static func parseCount(from line: String) -> Int? {
        let lower = line.lowercased()
        guard lower.contains("participant") || lower.contains("attendee") else { return nil }
        let pattern = #"(\d{1,3})"#
        if let match = line.range(of: pattern, options: .regularExpression) {
            return Int(line[match])
        }
        return nil
    }

    static func extractAgendaItems(from lines: [String]) -> [String] {
        var results: [String] = []
        var collecting = false

        for line in lines {
            let lower = line.lowercased()
            if lower.contains("agenda") || lower.hasPrefix("topics") || lower.hasPrefix("today") {
                collecting = true
                continue
            }

            if collecting {
                if isHeadingLine(line) {
                    break
                }
                if isBulletLine(line) {
                    results.append(stripBullet(from: line))
                }
            }
        }

        return results
    }

    static func extractParticipantNames(from lines: [String]) -> [String] {
        var results: [String] = []
        var collecting = false

        for line in lines {
            let lower = line.lowercased()
            if lower.contains("participants") || lower.contains("attendees") {
                collecting = true
                continue
            }

            if collecting {
                if isHeadingLine(line) {
                    break
                }
                if isLikelyName(line) {
                    results.append(line)
                }
            }
        }

        return results
    }

    static func extractSharedArtifacts(from lines: [String]) -> [String] {
        let extensions = [".pdf", ".doc", ".docx", ".ppt", ".pptx", ".xls", ".xlsx", ".txt", ".md"]
        var results: [String] = []

        for line in lines {
            let lower = line.lowercased()
            if lower.contains("shared") || lower.contains("file") || extensions.contains(where: { lower.contains($0) }) {
                results.append(line)
            }
        }

        return results
    }

    static func extractHeadings(from lines: [String]) -> [String] {
        var results: [String] = []
        for line in lines where isHeadingLine(line) {
            results.append(line)
        }
        return results
    }

    static func extractNotes(from lines: [String]) -> [String] {
        var results: [String] = []
        for line in lines {
            let lower = line.lowercased()
            if lower.hasPrefix("note:") || lower.hasPrefix("notes:") || lower.hasPrefix("fyi") {
                results.append(line)
            }
        }
        return results
    }

    static func isHeadingLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.count > 60 { return false }
        if isBulletLine(trimmed) { return false }
        if trimmed.hasSuffix(":") { return true }
        let letters = trimmed.filter { $0.isLetter }
        guard !letters.isEmpty else { return false }
        let upperCount = letters.filter { $0.isUppercase }.count
        let upperRatio = Double(upperCount) / Double(letters.count)
        return upperRatio >= 0.7
    }

    static func isBulletLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("- ") || trimmed.hasPrefix("\u{2022}") || trimmed.range(of: #"^\d+[\.\)]\s"#, options: .regularExpression) != nil
    }

    static func stripBullet(from line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("- ") {
            return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        if trimmed.hasPrefix("\u{2022}") {
            return String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        if let range = trimmed.range(of: #"^\d+[\.\)]\s"#, options: .regularExpression) {
            return String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        return trimmed
    }

    static func isLikelyName(_ line: String) -> Bool {
        if line.count > 40 { return false }
        let letters = line.filter { $0.isLetter }
        if letters.count < 2 { return false }
        guard let first = line.first, first.isLetter else { return false }

        var digitCount = 0
        for ch in line {
            if ch.isNumber {
                digitCount += 1
                continue
            }
            if !(ch.isLetter || ch == " " || ch == "-" || ch == "'") {
                return false
            }
        }

        if digitCount > 2 { return false }

        return true
    }

    static func appendUnique(_ items: [String], to array: inout [String], limit: Int) {
        guard !items.isEmpty else { return }
        var seen = Set(array.map { $0.lowercased() })
        for item in items {
            let key = item.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            array.append(item)
            if array.count >= limit {
                break
            }
        }
    }
}

private enum ScreenContextRedactor {
    private static let emailRegex = try? NSRegularExpression(
        pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
        options: [.caseInsensitive]
    )
    private static let phoneRegex = try? NSRegularExpression(
        pattern: #"(?x)(?:\+?\d{1,3}[\s-]?)?(?:\(?\d{3}\)?[\s-]?)\d{3}[\s-]?\d{4}"#,
        options: []
    )

    static func redact(_ input: String) -> String {
        var output = input
        if let emailRegex {
            output = emailRegex.stringByReplacingMatches(
                in: output,
                range: NSRange(output.startIndex..., in: output),
                withTemplate: "[redacted]"
            )
        }
        if let phoneRegex {
            output = phoneRegex.stringByReplacingMatches(
                in: output,
                range: NSRange(output.startIndex..., in: output),
                withTemplate: "[redacted]"
            )
        }
        return output
    }
}
