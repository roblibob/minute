import Testing
@testable import MinuteCore

struct MeetingTypeClassifierParseTests {

    @Test
    func parseResponse_invalidOrMessyOutput_defaultsToGeneral() {
        let inputs = [
            "",
            "   \n\t  ",
            "Standup.",
            "\"Standup\"",
            "Standup (daily)",
            "Standup, Planning",
            "Standup\nPlanning",
            "General\n",
            "- Standup",
            "Return ONLY the category name: Standup"
        ]

        for input in inputs {
            #expect(MeetingTypeClassifier.parseResponse(input) == .general)
        }
    }

    @Test
    func parseResponse_trimsWhitespace_andMatchesCaseInsensitiveExactLabels() {
        let cases: [(String, MeetingType)] = [
            ("  standup  ", .standup),
            ("\nDESIGN REVIEW\n", .designReview),
            (" one-on-one ", .oneOnOne),
            ("presentation", .presentation),
            ("PLANNING", .planning),
            ("general", .general)
        ]

        for (input, expected) in cases {
            #expect(MeetingTypeClassifier.parseResponse(input) == expected)
        }
    }
}
