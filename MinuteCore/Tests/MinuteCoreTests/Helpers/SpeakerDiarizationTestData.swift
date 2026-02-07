import Foundation
@testable import MinuteCore

enum SpeakerDiarizationTestData {
    static func speakerSegments(_ segments: [(start: Double, end: Double, speakerId: Int)]) -> [SpeakerSegment] {
        segments.map { SpeakerSegment(startSeconds: $0.start, endSeconds: $0.end, speakerId: $0.speakerId) }
    }

    static func transcriptSegments(_ segments: [(start: Double, end: Double, text: String)]) -> [TranscriptSegment] {
        segments.map { TranscriptSegment(startSeconds: $0.start, endSeconds: $0.end, text: $0.text) }
    }

    static func attributedTranscriptSegments(
        _ segments: [(start: Double, end: Double, speakerId: Int, text: String)]
    ) -> [AttributedTranscriptSegment] {
        segments.map { AttributedTranscriptSegment(startSeconds: $0.start, endSeconds: $0.end, speakerId: $0.speakerId, text: $0.text) }
    }
}
