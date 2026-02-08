import Foundation

public enum YAMLFrontmatterCodec {
    public static func encodeOwnedParticipantKeys(_ frontmatter: MeetingParticipantFrontmatter) -> [String] {
        var lines: [String] = []

        if !frontmatter.participants.isEmpty {
            lines.append("participants:")
            for name in frontmatter.participants {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                lines.append("  - \(StringNormalizer.yamlDoubleQuoted(encodeObsidianWikiLink(trimmed)))")
            }
        }

        let entries = orderedSpeakerMapEntries(frontmatter)
        if !entries.isEmpty {
            lines.append("speaker_map:")
            for (speakerId, name) in entries {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                lines.append("  \"\(speakerId)\": \(StringNormalizer.yamlDoubleQuoted(trimmed))")
            }
        }

        if let order = frontmatter.speakerOrder, !order.isEmpty {
            lines.append("speaker_order:")
            for id in order {
                lines.append("  - \(id)")
            }
        }

        return lines
    }

    public static func decodeOwnedParticipantKeys(from frontmatterLines: [String]) -> MeetingParticipantFrontmatter {
        var participants: [String] = []
        var speakerMap: [Int: String] = [:]
        var speakerOrder: [Int] = []

        var index = 0
        while index < frontmatterLines.count {
            let line = frontmatterLines[index]

            if line == "participants:" {
                index += 1
                while index < frontmatterLines.count {
                    let item = frontmatterLines[index]
                    if isTopLevelKeyLine(item) {
                        break
                    }
                    if let value = parseYAMLListItem(item) {
                        let normalized = decodeObsidianWikiLink(value)
                        if !normalized.isEmpty {
                            participants.append(normalized)
                        }
                    }
                    index += 1
                }
                continue
            }

            if line == "speaker_map:" {
                index += 1
                while index < frontmatterLines.count {
                    let item = frontmatterLines[index]
                    if isTopLevelKeyLine(item) {
                        break
                    }
                    if let (key, value) = parseYAMLStringMapEntry(item), let intKey = Int(key) {
                        let decoded = decodeYAMLDoubleQuotedString(value)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        speakerMap[intKey] = decoded
                    }
                    index += 1
                }
                continue
            }

            if line == "speaker_order:" {
                index += 1
                while index < frontmatterLines.count {
                    let item = frontmatterLines[index]
                    if isTopLevelKeyLine(item) {
                        break
                    }
                    if let value = parseYAMLListItem(item), let id = Int(value) {
                        speakerOrder.append(id)
                    }
                    index += 1
                }
                continue
            }

            index += 1
        }

        let order: [Int]?
        if speakerOrder.isEmpty {
            order = nil
        } else {
            order = speakerOrder
        }
        return MeetingParticipantFrontmatter(participants: participants, speakerMap: speakerMap, speakerOrder: order)
    }

    private static func encodeObsidianWikiLink(_ name: String) -> String {
        let normalized = decodeObsidianWikiLink(name)
        return "[[\(normalized)]]"
    }

    private static func decodeObsidianWikiLink(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let scalar = decodeYAMLDoubleQuotedString(trimmed).trimmingCharacters(in: .whitespacesAndNewlines)
        guard scalar.count >= 4, scalar.hasPrefix("[["), scalar.hasSuffix("]]"),
              let end = scalar.index(scalar.endIndex, offsetBy: -2, limitedBy: scalar.startIndex) else {
            return scalar
        }

        let innerStart = scalar.index(scalar.startIndex, offsetBy: 2)
        let inner = scalar[innerStart..<end].trimmingCharacters(in: .whitespacesAndNewlines)
        return String(inner)
    }

    private static func decodeYAMLDoubleQuotedString(_ value: String) -> String {
        guard value.count >= 2,
              value.first == "\"",
              value.last == "\"" else {
            return value
        }

        let inner = value.dropFirst().dropLast()
        var result = ""
        result.reserveCapacity(inner.count)

        var index = inner.startIndex
        while index < inner.endIndex {
            let ch = inner[index]
            if ch == "\\", let nextIndex = inner.index(index, offsetBy: 1, limitedBy: inner.endIndex), nextIndex < inner.endIndex {
                let next = inner[nextIndex]
                switch next {
                case "n": result.append("\n")
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                default: result.append(next)
                }
                index = inner.index(after: nextIndex)
                continue
            }

            result.append(ch)
            index = inner.index(after: index)
        }

        return result
    }

    private static func orderedSpeakerMapEntries(_ frontmatter: MeetingParticipantFrontmatter) -> [(Int, String)] {
        let map = frontmatter.speakerMap
        guard !map.isEmpty else { return [] }

        var result: [(Int, String)] = []
        result.reserveCapacity(map.count)

        var seen: Set<Int> = []
        if let order = frontmatter.speakerOrder {
            for id in order {
                if let value = map[id] {
                    result.append((id, value))
                    seen.insert(id)
                }
            }
        }

        let remaining = map.keys
            .filter { !seen.contains($0) }
            .sorted()

        for id in remaining {
            if let value = map[id] {
                result.append((id, value))
            }
        }

        return result
    }

    private static func isTopLevelKeyLine(_ line: String) -> Bool {
        if line.isEmpty { return false }
        if line.first == " " || line.first == "\t" { return false }
        return line.contains(":")
    }

    private static func parseYAMLListItem(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("-") else { return nil }
        let value = trimmed.dropFirst(1).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : String(value)
    }

    private static func parseYAMLStringMapEntry(_ line: String) -> (String, String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let colon = trimmed.firstIndex(of: ":") else { return nil }

        let rawKey = trimmed[..<colon].trimmingCharacters(in: .whitespacesAndNewlines)
        let rawValue = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)

        let key = rawKey.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        let value = String(rawValue)

        guard !key.isEmpty else { return nil }
        return (key, value)
    }
}
