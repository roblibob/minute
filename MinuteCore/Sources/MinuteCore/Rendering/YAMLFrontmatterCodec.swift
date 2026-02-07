import Foundation

public enum YAMLFrontmatterCodec {
    public static func encodeOwnedParticipantKeys(_ frontmatter: MeetingParticipantFrontmatter) -> [String] {
        var lines: [String] = []

        if !frontmatter.participants.isEmpty {
            lines.append("participants:")
            for name in frontmatter.participants {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                lines.append("  - \(trimmed)")
            }
        }

        let entries = orderedSpeakerMapEntries(frontmatter)
        if !entries.isEmpty {
            lines.append("speaker_map:")
            for (speakerId, name) in entries {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                lines.append("  \"\(speakerId)\": \(trimmed)")
            }
        }

        return lines
    }

    public static func decodeOwnedParticipantKeys(from frontmatterLines: [String]) -> MeetingParticipantFrontmatter {
        var participants: [String] = []
        var speakerMap: [Int: String] = [:]

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
                        participants.append(value)
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
                        speakerMap[intKey] = value
                    }
                    index += 1
                }
                continue
            }

            index += 1
        }

        return MeetingParticipantFrontmatter(participants: participants, speakerMap: speakerMap)
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
        let value = rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        guard !key.isEmpty else { return nil }
        return (key, value)
    }
}
