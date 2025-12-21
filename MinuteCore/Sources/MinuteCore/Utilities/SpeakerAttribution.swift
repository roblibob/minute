import Foundation

public enum SpeakerAttribution {
    public static func attribute(
        transcriptSegments: [TranscriptSegment],
        speakerSegments: [SpeakerSegment]
    ) -> [AttributedTranscriptSegment] {
        guard !transcriptSegments.isEmpty, !speakerSegments.isEmpty else {
            return []
        }

        var attributed: [AttributedTranscriptSegment] = []
        attributed.reserveCapacity(transcriptSegments.count)

        var lastSpeakerId: Int? = nil
        var hasOverlap = false

        for transcript in transcriptSegments {
            let best = bestSpeaker(for: transcript, speakerSegments: speakerSegments)
            if let overlap = best?.overlapSeconds, overlap > 0 {
                hasOverlap = true
            }

            let speakerId = best?.speakerId ?? lastSpeakerId ?? speakerSegments.first?.speakerId ?? 0
            lastSpeakerId = speakerId

            let text = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            attributed.append(
                AttributedTranscriptSegment(
                    startSeconds: transcript.startSeconds,
                    endSeconds: transcript.endSeconds,
                    speakerId: speakerId,
                    text: text
                )
            )
        }

        guard hasOverlap else { return [] }
        return mergeAdjacent(attributed)
    }

    private static func bestSpeaker(for transcript: TranscriptSegment, speakerSegments: [SpeakerSegment]) -> (speakerId: Int, overlapSeconds: Double)? {
        var bestId: Int? = nil
        var bestOverlap: Double = 0

        for speaker in speakerSegments {
            let overlap = overlapSeconds(
                startA: transcript.startSeconds,
                endA: transcript.endSeconds,
                startB: speaker.startSeconds,
                endB: speaker.endSeconds
            )
            if overlap > bestOverlap {
                bestOverlap = overlap
                bestId = speaker.speakerId
            }
        }

        guard let bestId else { return nil }
        return (speakerId: bestId, overlapSeconds: bestOverlap)
    }

    private static func overlapSeconds(startA: Double, endA: Double, startB: Double, endB: Double) -> Double {
        let start = max(startA, startB)
        let end = min(endA, endB)
        return max(0, end - start)
    }

    private static func mergeAdjacent(_ segments: [AttributedTranscriptSegment]) -> [AttributedTranscriptSegment] {
        guard !segments.isEmpty else { return [] }

        var merged: [AttributedTranscriptSegment] = []
        merged.reserveCapacity(segments.count)

        for segment in segments {
            if let last = merged.last, last.speakerId == segment.speakerId {
                let combinedText = [last.text, segment.text]
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let combined = AttributedTranscriptSegment(
                    startSeconds: last.startSeconds,
                    endSeconds: segment.endSeconds,
                    speakerId: last.speakerId,
                    text: combinedText
                )
                merged[merged.count - 1] = combined
            } else {
                merged.append(segment)
            }
        }

        return merged
    }
}
