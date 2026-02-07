import Testing
@testable import MinuteCore

struct SpeakerAttributionDeterminismTests {
    @Test
    func whenOverlapTies_prefersLowestSpeakerId() {
        let transcript = SpeakerDiarizationTestData.transcriptSegments([
            (start: 0.0, end: 10.0, text: "Hello")
        ])

        // Both speakers overlap the transcript equally.
        let speakers = SpeakerDiarizationTestData.speakerSegments([
            (start: 0.0, end: 10.0, speakerId: 2),
            (start: 0.0, end: 10.0, speakerId: 1),
        ])

        let attributed = SpeakerAttribution.attribute(transcriptSegments: transcript, speakerSegments: speakers)
        #expect(attributed.count == 1)
        #expect(attributed[0].speakerId == 1)
    }

    @Test
    func whenSegmentHasNoOverlap_butSomeSegmentsDo_prefersLowestSpeakerIdAsDefault() {
        let transcript = SpeakerDiarizationTestData.transcriptSegments([
            (start: 0.0, end: 1.0, text: "No overlap"),
            (start: 10.0, end: 11.0, text: "Has overlap"),
        ])

        // Only the second transcript segment overlaps.
        let speakers = SpeakerDiarizationTestData.speakerSegments([
            (start: 10.0, end: 11.0, speakerId: 2),
            (start: 10.0, end: 11.0, speakerId: 1),
        ])

        let attributed = SpeakerAttribution.attribute(transcriptSegments: transcript, speakerSegments: speakers)
        #expect(attributed.count == 1)
        #expect(attributed[0].speakerId == 1)
        #expect(attributed[0].text.contains("No overlap"))
        #expect(attributed[0].text.contains("Has overlap"))
    }
}
