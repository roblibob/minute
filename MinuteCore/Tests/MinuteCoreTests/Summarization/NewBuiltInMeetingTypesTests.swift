import Foundation
import Testing
@testable import MinuteCore

/// Tests for the built-in meeting types added from field-tested meeting-notes
/// templates: interview (taken/given), all hands, and retrospective — plus the
/// store-level reconciliation that surfaces them in previously saved libraries.
struct NewBuiltInMeetingTypesTests {

    private let newTypes: [MeetingType] = [.interviewTaken, .interviewGiven, .allHands, .retrospective]

    @Test
    func promptFactory_returnsDedicatedStrategyForNewTypes() {
        #expect(PromptFactory.strategy(for: .interviewTaken) is InterviewTakenPromptStrategy)
        #expect(PromptFactory.strategy(for: .interviewGiven) is InterviewGivenPromptStrategy)
        #expect(PromptFactory.strategy(for: .allHands) is AllHandsPromptStrategy)
        #expect(PromptFactory.strategy(for: .retrospective) is RetrospectivePromptStrategy)
    }

    @Test
    func newStrategies_declareMatchingMeetingTypeAndJSONContract() {
        for type in newTypes {
            let strategy = PromptFactory.strategy(for: type)
            #expect(strategy.meetingType == type)

            let systemPrompt = strategy.systemPrompt()
            // The vault contract fields must all be requested from the model.
            for field in ["title", "date", "summary", "decisions", "action_items", "open_questions", "key_points"] {
                #expect(systemPrompt.contains(field), "\(type) prompt missing field \(field)")
            }
            #expect(systemPrompt.contains("JSON"))

            let userPrompt = strategy.userPrompt(for: "TRANSCRIPT-MARKER")
            #expect(userPrompt.contains("TRANSCRIPT-MARKER"))
        }
    }

    @Test
    func interviewStrategies_distinguishPerspective() {
        let taken = InterviewTakenPromptStrategy().systemPrompt()
        let given = InterviewGivenPromptStrategy().systemPrompt()

        #expect(taken.contains("INTERVIEWER"))
        #expect(given.contains("CANDIDATE"))
    }

    @Test
    func defaultLibrary_includesNewTypesAsActiveAutodetectEligibleBuiltIns() throws {
        let library = try MeetingTypeLibrary.default.validated()

        for type in newTypes {
            let definition = try #require(library.definition(for: type.rawValue), "missing \(type.rawValue)")
            #expect(definition.source == .builtIn)
            #expect(definition.status == .active)
            #expect(definition.autodetectEligible)
            #expect(definition.isDeletable == false)

            let profile = try #require(definition.classifierProfile)
            #expect(!profile.strongSignals.isEmpty)
        }
    }

    @Test
    func builtInDefinitions_useTypeSpecificClassifierSignals() {
        // Signals must be richer than the old displayName-lowercased default.
        for type in MeetingType.allCases where type != .autodetect && type != .general {
            let signals = MeetingTypeLibrary.defaultClassifierSignals(for: type)
            #expect(!signals.isEmpty, "\(type.rawValue) has no signals")
            #expect(signals != [type.displayName.lowercased()], "\(type.rawValue) still uses generic signal")
        }
    }

    @Test
    func defaultPromptComponents_forNewTypes_passValidation() throws {
        for type in newTypes {
            let components = MeetingTypeLibrary.defaultPromptComponents(for: type)
            let validated = try components.validated(typeID: type.rawValue)
            #expect(!validated.objective.isEmpty)
            #expect(!validated.summaryFocus.isEmpty)
            #expect(!validated.additionalGuidance.isEmpty)
        }
    }

    @Test
    func libraryStore_mergesNewBuiltInsIntoPreviouslySavedLibrary() throws {
        let suiteName = "NewBuiltInMeetingTypesTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Simulate a library saved by an older app version: only the original types.
        let oldTypes: [MeetingType] = [.autodetect, .general, .standup, .designReview, .oneOnOne, .presentation, .planning]
        let oldLibrary = MeetingTypeLibrary(
            definitions: oldTypes.map(MeetingTypeLibrary.builtInDefinition(for:)),
            defaultTypeId: MeetingType.autodetect.rawValue
        )
        let data = try JSONEncoder().encode(try oldLibrary.validated())
        defaults.set(data, forKey: "meetingTypeLibrary")

        let store = MeetingTypeLibraryStore(defaults: defaults, libraryKey: "meetingTypeLibrary")
        let loaded = store.load()

        for type in newTypes {
            #expect(loaded.definition(for: type.rawValue) != nil, "reconciliation missed \(type.rawValue)")
        }
        // Existing definitions are untouched.
        #expect(loaded.definition(for: MeetingType.general.rawValue) != nil)
    }

    @Test
    func libraryStore_reconciliationPreservesBuiltInOverridesAndCustomTypes() throws {
        let suiteName = "NewBuiltInMeetingTypesTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let oldTypes: [MeetingType] = [.autodetect, .general, .standup, .designReview, .oneOnOne, .presentation, .planning]
        var definitions = oldTypes.map(MeetingTypeLibrary.builtInDefinition(for:))

        // Override the general built-in.
        var overridden = definitions[1]
        overridden.promptComponents.objective = "My customized general objective."
        definitions[1] = overridden

        // Add a custom type.
        definitions.append(
            MeetingTypeDefinition(
                typeId: "custom-abc",
                displayName: "My Custom Type",
                source: .custom,
                isDeletable: true,
                isEditableName: true,
                autodetectEligible: false,
                promptComponents: PromptComponentSet(objective: "Custom objective", summaryFocus: "Custom focus")
            )
        )

        let library = MeetingTypeLibrary(definitions: definitions, defaultTypeId: MeetingType.autodetect.rawValue)
        let data = try JSONEncoder().encode(try library.validated())
        defaults.set(data, forKey: "meetingTypeLibrary")

        let store = MeetingTypeLibraryStore(defaults: defaults, libraryKey: "meetingTypeLibrary")
        let loaded = store.load()

        let general = try #require(loaded.definition(for: MeetingType.general.rawValue))
        #expect(general.promptComponents.objective == "My customized general objective.")
        #expect(loaded.definition(for: "custom-abc") != nil)
        #expect(loaded.definition(for: MeetingType.retrospective.rawValue) != nil)
    }

    @Test
    func enrichedGeneralComponents_carrySpeakerAttributionGuidance() {
        let components = MeetingTypeLibrary.defaultPromptComponents(for: .general)
        let guidance = components.additionalGuidance.lowercased()
        #expect(guidance.contains("direct address"))
        #expect(guidance.contains("third person"))
    }

    @Test
    func generalStrategy_carriesPortedRuleIntentions() {
        let prompt = GeneralPromptStrategy().systemPrompt()

        // Step 2: participant identification.
        #expect(prompt.contains("Identify Participants"))
        #expect(prompt.contains("keep the Speaker N label"))
        // Step 4 / rule 6: thoroughness including disagreements and reasoning.
        #expect(prompt.contains("disagreements, concerns, and unresolved debates"))
        #expect(prompt.contains("capture the reasoning"))
        // Rule 5: technical accuracy.
        #expect(prompt.contains("exactly as spoken"))
        // Rules 4/7: screen capture context.
        #expect(prompt.contains("Use Screen Context"))
        // Rule 2: action item dates.
        #expect(prompt.contains("Use \"TBD\" when no date was mentioned"))
        // Rule 6 phrasing: better to include too much.
        #expect(prompt.contains("Better Too Much Than Missing"))
    }
}
