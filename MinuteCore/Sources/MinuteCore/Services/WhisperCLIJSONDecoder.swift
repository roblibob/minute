import Foundation

enum WhisperCLIJSONDecoder {
    struct Output: Sendable {
        let text: String
        let segments: [TranscriptSegment]
    }

    static func decode(data: Data) -> Output? {
        guard let root = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return nil
        }

        let segmentDictionaries: [[String: Any]]
        if let dict = root as? [String: Any] {
            if let transcription = dict["transcription"] as? [Any] {
                segmentDictionaries = transcription.compactMap { $0 as? [String: Any] }
            } else if let segments = dict["segments"] as? [Any] {
                segmentDictionaries = segments.compactMap { $0 as? [String: Any] }
            } else {
                segmentDictionaries = []
            }
        } else if let array = root as? [Any] {
            segmentDictionaries = array.compactMap { $0 as? [String: Any] }
        } else {
            segmentDictionaries = []
        }

        var combined = ""
        var segments: [TranscriptSegment] = []
        segments.reserveCapacity(segmentDictionaries.count)

        for segment in segmentDictionaries {
            guard let text = segment["text"] as? String else { continue }
            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { continue }

            if !combined.isEmpty {
                combined.append(" ")
            }
            combined.append(cleaned)

            if let (startSeconds, endSeconds) = extractSegmentTimes(segment) {
                segments.append(
                    TranscriptSegment(startSeconds: startSeconds, endSeconds: endSeconds, text: cleaned)
                )
            }
        }

        if combined.isEmpty, let dict = root as? [String: Any], let text = dict["text"] as? String {
            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                let normalized = TranscriptNormalizer.normalizeWhisperOutput(cleaned)
                return Output(text: normalized, segments: [])
            }
        }

        guard !combined.isEmpty else {
            return nil
        }

        let normalized = TranscriptNormalizer.normalizeWhisperOutput(combined)
        return Output(text: normalized, segments: segments)
    }

    private static func extractSegmentTimes(_ segment: [String: Any]) -> (Double, Double)? {
        if let offsets = segment["offsets"] as? [String: Any],
           let startMs = numberFrom(offsets["from"]),
           let endMs = numberFrom(offsets["to"]) {
            return (startMs / 1000.0, endMs / 1000.0)
        }

        if let timestamps = segment["timestamps"] as? [String: Any],
           let startValue = timestamps["from"],
           let endValue = timestamps["to"] {
            if let startSeconds = parseTimestampValue(startValue),
               let endSeconds = parseTimestampValue(endValue) {
                return (startSeconds, endSeconds)
            }
        }

        if let startValue = segment["start"],
           let endValue = segment["end"],
           let start = numberFrom(startValue),
           let end = numberFrom(endValue) {
            let scale: Double = max(start, end) > 1_000.0 ? 1000.0 : 1.0
            return (start / scale, end / scale)
        }

        return nil
    }

    private static func numberFrom(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return parseTimestampValue(string)
        default:
            return nil
        }
    }

    private static func parseTimestampValue(_ value: Any) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }

        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if trimmed.contains(":") {
                let parts = trimmed.split(separator: ":")
                guard !parts.isEmpty else { return nil }
                var seconds = 0.0
                for part in parts {
                    seconds = seconds * 60.0 + (Double(part) ?? 0.0)
                }
                return seconds
            }
            return Double(trimmed)
        }

        return nil
    }
}
