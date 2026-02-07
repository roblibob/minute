import Testing
@testable import MinuteCore

struct MeetingTypeClassifierTests {

    @Test
    func promptGeneration() {
        let snippet = "Alice: What did you do yesterday?\nBob: I fixed the bug."
        let prompt = MeetingTypeClassifier.prompt(for: snippet)

        #expect(prompt.contains(snippet))
        #expect(prompt.contains("General"))
        #expect(prompt.contains("Standup"))
        #expect(prompt.contains("Design Review"))
        #expect(prompt.contains("One-on-One"))
        #expect(prompt.contains("Presentation"))
        #expect(prompt.contains("Planning"))

        #expect(prompt.lowercased().contains("if"))
        #expect(prompt.lowercased().contains("uncertain"))
        #expect(prompt.contains("General"))
        #expect(prompt.lowercased().contains("return only"))
    }

    @Test
    func responseParsing() {
        let cases: [(String, MeetingType)] = [
            ("Standup", .standup),
            ("standup", .standup),
            ("Design Review", .designReview),
            ("One-on-One", .oneOnOne),
            ("Planning", .planning),
            ("Presentation", .presentation),
            ("Unknown", .general),
            ("General", .general),
            ("This is a Standup", .general),
            ("Design", .general),
            ("1:1", .general),
            ("Roadmap", .general),
            ("Talk", .general)
        ]

        for (input, expected) in cases {
            let result = MeetingTypeClassifier.parseResponse(input)
            #expect(result == expected)
        }
    }

    @Test
    func prompt_includesLowInformationDefaultsToGeneralExamples() {
        let prompt = MeetingTypeClassifier.prompt(for: "Hello")

        for snippet in MeetingTypeClassifierSnippets.lowInformation {
            #expect(prompt.contains("\"\(snippet)\" => General"))
        }
    }

    @Test
    func prompt_includesMixedSignalsDefaultsToGeneralExamples() {
        let prompt = MeetingTypeClassifier.prompt(for: "Hello")

        for snippet in MeetingTypeClassifierSnippets.mixedSignals {
            #expect(prompt.contains("\"\(snippet)\" => General"))
        }
    }

    @Test
    func prompt_includesKeywordTrapDefaultsToGeneralExamples() {
        let prompt = MeetingTypeClassifier.prompt(for: "Hello")

        for snippet in MeetingTypeClassifierSnippets.keywordTraps {
            #expect(prompt.contains("\"\(snippet)\" => General"))
        }
    }

    @Test
    func prompt_includesClearStandupExamples() {
        let prompt = MeetingTypeClassifier.prompt(for: "Hello")

        for snippet in MeetingTypeClassifierSnippets.clearStandup {
            #expect(prompt.contains("\"\(snippet)\" => Standup"))
        }
    }

    @Test
    func prompt_includesClearPresentationExamples() {
        let prompt = MeetingTypeClassifier.prompt(for: "Hello")

        for snippet in MeetingTypeClassifierSnippets.clearPresentation {
            #expect(prompt.contains("\"\(snippet)\" => Presentation"))
        }
    }

    @Test
    func prompt_includesClearPlanningExamples() {
        let prompt = MeetingTypeClassifier.prompt(for: "Hello")

        for snippet in MeetingTypeClassifierSnippets.clearPlanning {
            #expect(prompt.contains("\"\(snippet)\" => Planning"))
        }
    }

    @Test
    func prompt_includesClearOneOnOneExamples() {
        let prompt = MeetingTypeClassifier.prompt(for: "Hello")

        for snippet in MeetingTypeClassifierSnippets.clearOneOnOne {
            #expect(prompt.contains("\"\(snippet)\" => One-on-One"))
        }
    }

    @Test
    func prompt_includesClearDesignReviewExamples() {
        let prompt = MeetingTypeClassifier.prompt(for: "Hello")

        for snippet in MeetingTypeClassifierSnippets.clearDesignReview {
            #expect(prompt.contains("\"\(snippet)\" => Design Review"))
        }
    }
}
