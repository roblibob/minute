import Foundation

public struct MeetingTimelineEntry: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case transcript(speakerId: Int, text: String)
        case screen(windowTitle: String, inference: ScreenContextInference)
    }

    public var timestampSeconds: Double
    public var kind: Kind

    public init(timestampSeconds: Double, kind: Kind) {
        self.timestampSeconds = timestampSeconds
        self.kind = kind
    }
}

public enum MeetingTimelineBuilder {
    public static func build(
        transcriptSegments: [AttributedTranscriptSegment],
        screenEvents: [ScreenContextEvent]
    ) -> [MeetingTimelineEntry] {
        var entries: [MeetingTimelineEntry] = []
        entries.reserveCapacity(transcriptSegments.count + screenEvents.count)

        for segment in transcriptSegments {
            let trimmed = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            entries.append(
                MeetingTimelineEntry(
                    timestampSeconds: max(0, segment.startSeconds),
                    kind: .transcript(speakerId: segment.speakerId, text: trimmed)
                )
            )
        }

        for event in screenEvents {
            guard !event.inference.isEmpty else { continue }
            entries.append(
                MeetingTimelineEntry(
                    timestampSeconds: max(0, event.timestampSeconds),
                    kind: .screen(windowTitle: event.windowTitle, inference: event.inference)
                )
            )
        }

        entries.sort { lhs, rhs in
            if lhs.timestampSeconds == rhs.timestampSeconds {
                return lhs.sortIndex < rhs.sortIndex
            }
            return lhs.timestampSeconds < rhs.timestampSeconds
        }

        return entries
    }
}

public struct MeetingTimelineRenderer: Sendable {
    public init() {}

    public func render(entries: [MeetingTimelineEntry]) -> String {
        let lines = entries.compactMap { entry -> String? in
            let timestamp = formatTime(entry.timestampSeconds)
            switch entry.kind {
            case .transcript(let speakerId, let text):
                let speakerLabel = "Speaker \(speakerId + 1)"
                return "[\(timestamp)] \(speakerLabel): \(text)"
            case .screen(_, let inference):
                let summary = inference.summaryLine()
                guard !summary.isEmpty else { return nil }
                return "[\(timestamp)] Screen context - \(summary)"
            }
        }

        return lines.joined(separator: "\n")
    }
}

private extension MeetingTimelineEntry {
    var sortIndex: Int {
        switch kind {
        case .transcript:
            return 0
        case .screen:
            return 1
        }
    }
}

private func formatTime(_ seconds: Double) -> String {
    let totalSeconds = max(0, Int(seconds.rounded(.down)))
    let minutes = totalSeconds / 60
    let secs = totalSeconds % 60
    return String(format: "%02d:%02d", minutes, secs)
}
