import Testing
@testable import MinuteCore

struct SpeakerOrderingTests {
    @Test
    func orderedSpeakerIDs_sortsByDurationDesc_thenEarliestStartAsc_thenSpeakerIdAsc() {
        let segments: [SpeakerSegment] = [
            // Speaker 2 total 4s, earliest 0
            SpeakerSegment(startSeconds: 0, endSeconds: 2, speakerId: 2),
            SpeakerSegment(startSeconds: 10, endSeconds: 12, speakerId: 2),

            // Speaker 1 total 4s, earliest 5 (tie duration, later start)
            SpeakerSegment(startSeconds: 5, endSeconds: 9, speakerId: 1),

            // Speaker 3 total 4s, earliest 5 (tie duration & earliest, higher id)
            SpeakerSegment(startSeconds: 5, endSeconds: 9, speakerId: 3),
        ]

        let ordered = SpeakerOrdering.orderedSpeakerIDs(from: segments)
        expectEqual(ordered, [2, 1, 3])
    }

    @Test
    func orderedSpeakerIDs_isDeterministicRegardlessOfInputOrder() {
        let a: [SpeakerSegment] = [
            SpeakerSegment(startSeconds: 0, endSeconds: 4, speakerId: 1),
            SpeakerSegment(startSeconds: 4, endSeconds: 6, speakerId: 2),
            SpeakerSegment(startSeconds: 6, endSeconds: 10, speakerId: 2),
        ]

        let b: [SpeakerSegment] = [
            SpeakerSegment(startSeconds: 6, endSeconds: 10, speakerId: 2),
            SpeakerSegment(startSeconds: 0, endSeconds: 4, speakerId: 1),
            SpeakerSegment(startSeconds: 4, endSeconds: 6, speakerId: 2),
        ]

        let orderedA = SpeakerOrdering.orderedSpeakerIDs(from: a)
        let orderedB = SpeakerOrdering.orderedSpeakerIDs(from: b)
        expectEqual(orderedA, orderedB)
        expectEqual(orderedA, [2, 1])
    }
}
