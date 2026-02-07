import Foundation

public enum SpeakerOrdering {
    /// Orders speaker IDs deterministically per FR-002a:
    /// 1) Total speaking duration (desc)
    /// 2) Earliest segment start (asc)
    /// 3) Stable speaker ID (asc)
    public static func orderedSpeakerIDs(from speakerSegments: [SpeakerSegment]) -> [Int] {
        guard !speakerSegments.isEmpty else { return [] }

        struct Aggregate {
            var durationSeconds: Double
            var earliestStartSeconds: Double
        }

        var aggregates: [Int: Aggregate] = [:]
        aggregates.reserveCapacity(8)

        for segment in speakerSegments {
            let duration = max(0, segment.endSeconds - segment.startSeconds)
            let start = segment.startSeconds

            if var aggregate = aggregates[segment.speakerId] {
                aggregate.durationSeconds += duration
                aggregate.earliestStartSeconds = min(aggregate.earliestStartSeconds, start)
                aggregates[segment.speakerId] = aggregate
            } else {
                aggregates[segment.speakerId] = Aggregate(durationSeconds: duration, earliestStartSeconds: start)
            }
        }

        return aggregates
            .map { (speakerId: $0.key, duration: $0.value.durationSeconds, earliestStart: $0.value.earliestStartSeconds) }
            .sorted { lhs, rhs in
                if lhs.duration != rhs.duration { return lhs.duration > rhs.duration }
                if lhs.earliestStart != rhs.earliestStart { return lhs.earliestStart < rhs.earliestStart }
                return lhs.speakerId < rhs.speakerId
            }
            .map { $0.speakerId }
    }
}
