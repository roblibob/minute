import Foundation

public enum MeetingTypeLibraryValidationError: Error, Sendable, Equatable {
    case invalidTypeID
    case emptyDisplayName(typeID: String)
    case duplicateTypeID(String)
    case duplicateDisplayName(String)
    case missingPromptObjective(typeID: String)
    case missingPromptSummaryFocus(typeID: String)
    case autodetectClassifierMissing(typeID: String)
    case autodetectClassifierSignalsMissing(typeID: String)
}

private extension String {
    var minuteTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Array where Element == String {
    func minuteNormalizedTerms() -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        result.reserveCapacity(count)

        for raw in self {
            let trimmed = raw.minuteTrimmed
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { continue }
            result.append(trimmed)
        }

        return result
    }
}

public enum MeetingTypeDefinitionSource: String, Codable, Sendable, Equatable {
    case builtIn = "built_in"
    case custom
}

public enum MeetingTypeDefinitionStatus: String, Codable, Sendable, Equatable {
    case active
    case archived
    case deleted
}

public struct PromptComponentSet: Codable, Sendable, Equatable {
    public var objective: String
    public var summaryFocus: String
    public var decisionRulesEnabled: Bool
    public var decisionRules: String
    public var actionItemRulesEnabled: Bool
    public var actionItemRules: String
    public var openQuestionRulesEnabled: Bool
    public var openQuestionRules: String
    public var keyPointRulesEnabled: Bool
    public var keyPointRules: String
    public var noiseFilterRules: String
    public var additionalGuidance: String
    public var version: Int

    public init(
        objective: String,
        summaryFocus: String,
        decisionRulesEnabled: Bool = true,
        decisionRules: String = "",
        actionItemRulesEnabled: Bool = true,
        actionItemRules: String = "",
        openQuestionRulesEnabled: Bool = true,
        openQuestionRules: String = "",
        keyPointRulesEnabled: Bool = true,
        keyPointRules: String = "",
        noiseFilterRules: String = "",
        additionalGuidance: String = "",
        version: Int = 1
    ) {
        self.objective = objective
        self.summaryFocus = summaryFocus
        self.decisionRulesEnabled = decisionRulesEnabled
        self.decisionRules = decisionRules
        self.actionItemRulesEnabled = actionItemRulesEnabled
        self.actionItemRules = actionItemRules
        self.openQuestionRulesEnabled = openQuestionRulesEnabled
        self.openQuestionRules = openQuestionRules
        self.keyPointRulesEnabled = keyPointRulesEnabled
        self.keyPointRules = keyPointRules
        self.noiseFilterRules = noiseFilterRules
        self.additionalGuidance = additionalGuidance
        self.version = max(version, 1)
    }

    private enum CodingKeys: String, CodingKey {
        case objective
        case summaryFocus
        case decisionRulesEnabled
        case decisionRules
        case actionItemRulesEnabled
        case actionItemRules
        case openQuestionRulesEnabled
        case openQuestionRules
        case keyPointRulesEnabled
        case keyPointRules
        case noiseFilterRules
        case additionalGuidance
        case version
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        objective = try container.decode(String.self, forKey: .objective)
        summaryFocus = try container.decode(String.self, forKey: .summaryFocus)
        decisionRulesEnabled = try container.decodeIfPresent(Bool.self, forKey: .decisionRulesEnabled) ?? true
        decisionRules = try container.decodeIfPresent(String.self, forKey: .decisionRules) ?? ""
        actionItemRulesEnabled = try container.decodeIfPresent(Bool.self, forKey: .actionItemRulesEnabled) ?? true
        actionItemRules = try container.decodeIfPresent(String.self, forKey: .actionItemRules) ?? ""
        openQuestionRulesEnabled = try container.decodeIfPresent(Bool.self, forKey: .openQuestionRulesEnabled) ?? true
        openQuestionRules = try container.decodeIfPresent(String.self, forKey: .openQuestionRules) ?? ""
        keyPointRulesEnabled = try container.decodeIfPresent(Bool.self, forKey: .keyPointRulesEnabled) ?? true
        keyPointRules = try container.decodeIfPresent(String.self, forKey: .keyPointRules) ?? ""
        noiseFilterRules = try container.decodeIfPresent(String.self, forKey: .noiseFilterRules) ?? ""
        additionalGuidance = try container.decodeIfPresent(String.self, forKey: .additionalGuidance) ?? ""
        version = max((try container.decodeIfPresent(Int.self, forKey: .version) ?? 1), 1)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(objective, forKey: .objective)
        try container.encode(summaryFocus, forKey: .summaryFocus)
        try container.encode(decisionRulesEnabled, forKey: .decisionRulesEnabled)
        try container.encode(decisionRules, forKey: .decisionRules)
        try container.encode(actionItemRulesEnabled, forKey: .actionItemRulesEnabled)
        try container.encode(actionItemRules, forKey: .actionItemRules)
        try container.encode(openQuestionRulesEnabled, forKey: .openQuestionRulesEnabled)
        try container.encode(openQuestionRules, forKey: .openQuestionRules)
        try container.encode(keyPointRulesEnabled, forKey: .keyPointRulesEnabled)
        try container.encode(keyPointRules, forKey: .keyPointRules)
        try container.encode(noiseFilterRules, forKey: .noiseFilterRules)
        try container.encode(additionalGuidance, forKey: .additionalGuidance)
        try container.encode(max(version, 1), forKey: .version)
    }

    public var summarySectionVisibility: MeetingSummarySectionVisibility {
        MeetingSummarySectionVisibility(
            decisions: decisionRulesEnabled,
            actionItems: actionItemRulesEnabled,
            openQuestions: openQuestionRulesEnabled,
            keyPoints: keyPointRulesEnabled
        )
    }

    public func validated(typeID: String = "unknown") throws -> PromptComponentSet {
        let normalized = PromptComponentSet(
            objective: objective.minuteTrimmed,
            summaryFocus: summaryFocus.minuteTrimmed,
            decisionRulesEnabled: decisionRulesEnabled,
            decisionRules: decisionRules.minuteTrimmed,
            actionItemRulesEnabled: actionItemRulesEnabled,
            actionItemRules: actionItemRules.minuteTrimmed,
            openQuestionRulesEnabled: openQuestionRulesEnabled,
            openQuestionRules: openQuestionRules.minuteTrimmed,
            keyPointRulesEnabled: keyPointRulesEnabled,
            keyPointRules: keyPointRules.minuteTrimmed,
            noiseFilterRules: noiseFilterRules.minuteTrimmed,
            additionalGuidance: additionalGuidance.minuteTrimmed,
            version: max(version, 1)
        )

        guard !normalized.objective.isEmpty else {
            throw MeetingTypeLibraryValidationError.missingPromptObjective(typeID: typeID)
        }
        guard !normalized.summaryFocus.isEmpty else {
            throw MeetingTypeLibraryValidationError.missingPromptSummaryFocus(typeID: typeID)
        }

        return normalized
    }
}

public struct ClassifierProfile: Codable, Sendable, Equatable {
    public var label: String
    public var strongSignals: [String]
    public var counterSignals: [String]
    public var positiveExamples: [String]
    public var negativeExamples: [String]

    public init(
        label: String,
        strongSignals: [String],
        counterSignals: [String] = [],
        positiveExamples: [String] = [],
        negativeExamples: [String] = []
    ) {
        self.label = label
        self.strongSignals = strongSignals
        self.counterSignals = counterSignals
        self.positiveExamples = positiveExamples
        self.negativeExamples = negativeExamples
    }

    public func validated(typeID: String, requiresSignals: Bool) throws -> ClassifierProfile {
        let normalized = ClassifierProfile(
            label: label.minuteTrimmed,
            strongSignals: strongSignals.minuteNormalizedTerms(),
            counterSignals: counterSignals.minuteNormalizedTerms(),
            positiveExamples: positiveExamples.minuteNormalizedTerms(),
            negativeExamples: negativeExamples.minuteNormalizedTerms()
        )

        guard !requiresSignals || !normalized.label.isEmpty else {
            throw MeetingTypeLibraryValidationError.autodetectClassifierMissing(typeID: typeID)
        }
        guard !requiresSignals || !normalized.strongSignals.isEmpty else {
            throw MeetingTypeLibraryValidationError.autodetectClassifierSignalsMissing(typeID: typeID)
        }

        return normalized
    }
}

public struct MeetingTypeDefinition: Codable, Sendable, Equatable {
    public var typeId: String
    public var displayName: String
    public var source: MeetingTypeDefinitionSource
    public var isDeletable: Bool
    public var isEditableName: Bool
    public var autodetectEligible: Bool
    public var promptComponents: PromptComponentSet
    public var classifierProfile: ClassifierProfile?
    public var updatedAt: Date
    public var status: MeetingTypeDefinitionStatus

    public init(
        typeId: String,
        displayName: String,
        source: MeetingTypeDefinitionSource,
        isDeletable: Bool,
        isEditableName: Bool,
        autodetectEligible: Bool,
        promptComponents: PromptComponentSet,
        classifierProfile: ClassifierProfile? = nil,
        updatedAt: Date = Date(),
        status: MeetingTypeDefinitionStatus = .active
    ) {
        self.typeId = typeId
        self.displayName = displayName
        self.source = source
        self.isDeletable = isDeletable
        self.isEditableName = isEditableName
        self.autodetectEligible = autodetectEligible
        self.promptComponents = promptComponents
        self.classifierProfile = classifierProfile
        self.updatedAt = updatedAt
        self.status = status
    }

    public func validated() throws -> MeetingTypeDefinition {
        let normalizedTypeID = typeId.minuteTrimmed
        guard !normalizedTypeID.isEmpty else {
            throw MeetingTypeLibraryValidationError.invalidTypeID
        }

        let normalizedName = displayName.minuteTrimmed
        guard !normalizedName.isEmpty else {
            throw MeetingTypeLibraryValidationError.emptyDisplayName(typeID: normalizedTypeID)
        }

        let normalizedPromptComponents = try promptComponents.validated(typeID: normalizedTypeID)
        let normalizedClassifierProfile = try classifierProfile?.validated(
            typeID: normalizedTypeID,
            requiresSignals: autodetectEligible
        )
        if autodetectEligible && normalizedClassifierProfile == nil {
            throw MeetingTypeLibraryValidationError.autodetectClassifierMissing(typeID: normalizedTypeID)
        }

        let normalizedStatus: MeetingTypeDefinitionStatus = {
            if source == .builtIn && status == .deleted {
                return .active
            }
            return status
        }()

        return MeetingTypeDefinition(
            typeId: normalizedTypeID,
            displayName: normalizedName,
            source: source,
            isDeletable: source == .custom,
            isEditableName: source == .custom,
            autodetectEligible: autodetectEligible,
            promptComponents: normalizedPromptComponents,
            classifierProfile: normalizedClassifierProfile,
            updatedAt: updatedAt,
            status: normalizedStatus
        )
    }
}

public struct BuiltInPromptOverride: Codable, Sendable, Equatable {
    public var typeId: String
    public var defaultComponents: PromptComponentSet
    public var overrideComponents: PromptComponentSet
    public var isOverridden: Bool
    public var updatedAt: Date

    public init(
        typeId: String,
        defaultComponents: PromptComponentSet,
        overrideComponents: PromptComponentSet,
        isOverridden: Bool,
        updatedAt: Date = Date()
    ) {
        self.typeId = typeId
        self.defaultComponents = defaultComponents
        self.overrideComponents = overrideComponents
        self.isOverridden = isOverridden
        self.updatedAt = updatedAt
    }
}

public struct MeetingTypeLibrary: Codable, Sendable, Equatable {
    public var definitions: [MeetingTypeDefinition]
    public var defaultTypeId: String
    public var libraryVersion: Int
    public var updatedAt: Date

    public init(
        definitions: [MeetingTypeDefinition],
        defaultTypeId: String = MeetingType.autodetect.rawValue,
        libraryVersion: Int = 1,
        updatedAt: Date = Date()
    ) {
        self.definitions = definitions
        self.defaultTypeId = defaultTypeId
        self.libraryVersion = max(libraryVersion, 1)
        self.updatedAt = updatedAt
    }

    public static var `default`: MeetingTypeLibrary {
        MeetingTypeLibrary(
            definitions: MeetingType.allCases.map(Self.builtInDefinition(for:)),
            defaultTypeId: MeetingType.autodetect.rawValue
        )
    }

    public var activeDefinitions: [MeetingTypeDefinition] {
        definitions.filter { $0.status == .active }
    }

    public func definition(for typeID: String) -> MeetingTypeDefinition? {
        definitions.first { $0.typeId == typeID }
    }

    public func containsDisplayName(_ displayName: String, excludingTypeID: String? = nil) -> Bool {
        let key = displayName.minuteTrimmed.lowercased()
        guard !key.isEmpty else { return false }
        return activeDefinitions.contains { definition in
            guard definition.typeId != excludingTypeID else { return false }
            return definition.displayName.lowercased() == key
        }
    }

    public func isBuiltInOverridden(typeID: String) -> Bool {
        guard let definition = definition(for: typeID), definition.source == .builtIn else {
            return false
        }
        guard let baseType = MeetingType(rawValue: typeID) else {
            return false
        }
        let defaultDefinition = Self.builtInDefinition(for: baseType)
        return definition.promptComponents != defaultDefinition.promptComponents
    }

    public func validated() throws -> MeetingTypeLibrary {
        var seenTypeIDs: Set<String> = []
        var seenDisplayNames: Set<String> = []
        var normalizedDefinitions: [MeetingTypeDefinition] = []
        normalizedDefinitions.reserveCapacity(definitions.count)

        for definition in definitions {
            let normalized = try definition.validated()

            guard seenTypeIDs.insert(normalized.typeId).inserted else {
                throw MeetingTypeLibraryValidationError.duplicateTypeID(normalized.typeId)
            }

            if normalized.status == .active {
                let nameKey = normalized.displayName.lowercased()
                guard seenDisplayNames.insert(nameKey).inserted else {
                    throw MeetingTypeLibraryValidationError.duplicateDisplayName(normalized.displayName)
                }
            }

            normalizedDefinitions.append(normalized)
        }

        let sortedDefinitions = sortDefinitions(normalizedDefinitions)
        let activeTypeIDs = Set(sortedDefinitions.filter { $0.status == .active }.map(\.typeId))
        let fallbackTypeID = sortedDefinitions.first(where: { $0.status == .active })?.typeId
            ?? MeetingType.autodetect.rawValue

        let normalizedDefaultTypeID = defaultTypeId.minuteTrimmed
        let resolvedDefaultTypeID: String
        if activeTypeIDs.contains(normalizedDefaultTypeID) {
            resolvedDefaultTypeID = normalizedDefaultTypeID
        } else {
            resolvedDefaultTypeID = fallbackTypeID
        }

        return MeetingTypeLibrary(
            definitions: sortedDefinitions,
            defaultTypeId: resolvedDefaultTypeID,
            libraryVersion: max(libraryVersion, 1),
            updatedAt: updatedAt
        )
    }

    public static func builtInDefinition(for type: MeetingType) -> MeetingTypeDefinition {
        MeetingTypeDefinition(
            typeId: type.rawValue,
            displayName: type.displayName,
            source: .builtIn,
            isDeletable: false,
            isEditableName: false,
            autodetectEligible: type != .autodetect,
            promptComponents: defaultPromptComponents(for: type),
            classifierProfile: type == .autodetect ? nil : ClassifierProfile(
                label: type.displayName,
                strongSignals: defaultClassifierSignals(for: type)
            ),
            status: .active
        )
    }

    /// Strong autodetect signals per built-in type, derived from detection
    /// heuristics refined through real meeting-notes usage.
    public static func defaultClassifierSignals(for type: MeetingType) -> [String] {
        switch type {
        case .autodetect:
            return []
        case .general:
            return ["general"]
        case .standup:
            return [
                "explicit standup/daily mention",
                "yesterday/today/blockers round-robin status updates"
            ]
        case .designReview:
            return [
                "explicit design review mention",
                "critique of mockups/UX/architecture proposals",
                "trade-offs discussed with concerns raised and resolved"
            ]
        case .oneOnOne:
            return [
                "explicit 1:1 mention",
                "exactly two participants with informal topic jumps between personal and project updates",
                "manager-report feedback, career check-in, or growth-plan discussion"
            ]
        case .presentation:
            return [
                "one person speaks mostly with slides or demos referenced",
                "speaker-led narrative with audience Q&A at the end"
            ]
        case .planning:
            return [
                "sprint/roadmap planning with estimation and ticketing",
                "task allocation with owners, timelines, and scope"
            ]
        case .interviewTaken:
            return [
                "structured Q&A posing coding or design problems to evaluate a candidate",
                "introductions mentioning an interview round with the transcript owner asking the questions",
                "evaluation language about candidate strengths and hiring signal"
            ]
        case .interviewGiven:
            return [
                "structured Q&A with the transcript owner answering coding or design problems",
                "introductions mentioning an interview round with the owner being evaluated",
                "interviewer giving hints, redirections, or asking follow-up probes"
            ]
        case .allHands:
            return [
                "explicit all-hands or town-hall mention",
                "large audience implied with leadership speaking",
                "company or org-wide updates with metrics and audience Q&A"
            ]
        case .retrospective:
            return [
                "explicit retro/retrospective/post-mortem mention",
                "what went well / what didn't go well / what to improve structure",
                "lessons learned discussion about a completed sprint or project"
            ]
        }
    }

    public static func defaultPromptComponents(for type: MeetingType) -> PromptComponentSet {
        // Shared guidance derived from field-tested meeting-notes generation rules:
        // speaker attribution, garbled-ASR handling, and technical accuracy.
        let attributionGuidance = """
        Identify participants carefully before assigning statements: direct address by name is the strongest identity evidence; a person mentioned in third person is almost certainly not the speaker; role signals (assigning goals, giving feedback vs. receiving coaching, giving status) distinguish manager from report. Attribute positions to the right person — who gave advice vs. who received it. Transcripts may be code-mixed or contain heavy ASR errors: read past garbling to recover intent, and never invent a confident reading for an unresolvable name or phrase. Preserve project names, service names, team names, and technical terms exactly as spoken.
        """

        switch type {
        case .autodetect:
            return PromptComponentSet(
                objective: "Use a balanced default summary style when meeting type is unresolved.",
                summaryFocus: "Capture outcomes, decisions, action items, open questions, and key points."
            )
        case .general:
            return PromptComponentSet(
                objective: "Create a factual executive summary for a general business meeting.",
                summaryFocus: "Prioritize meeting outcomes, decisions, and assigned follow-ups. Capture ALL distinct topics, even brief ones, including disagreements, concerns, and unresolved debates.",
                decisionRules: "Only list explicit agreements or conclusions reached, with rationale when stated.",
                actionItemRules: "Only list clear commitments to perform a task. Start each task with a verb; name the owner when stated and never guess names.",
                openQuestionRules: "List unresolved issues and topics explicitly tabled for later.",
                keyPointRules: "Capture notable facts, constraints, data points, and context essential to understanding the meeting, including the reasoning behind guidance or advice given.",
                noiseFilterRules: "Ignore small talk, pleasantries, and non-substantive filler.",
                additionalGuidance: attributionGuidance
            )
        case .standup:
            return PromptComponentSet(
                objective: "Summarize daily standup progress accurately.",
                summaryFocus: "Highlight yesterday/today updates and blockers by speaker where possible. Capture status updates, risks, and cross-team dependencies.",
                actionItemRules: "Capture committed follow-ups with owners; do not convert routine status into action items.",
                keyPointRules: "Capture blockers with owner and impact, and any mitigation discussed.",
                additionalGuidance: attributionGuidance
            )
        case .designReview:
            return PromptComponentSet(
                objective: "Summarize design review feedback and outcomes.",
                summaryFocus: "Emphasize the proposal reviewed, approved changes, critiques, trade-offs discussed, unresolved design questions, and follow-ups.",
                decisionRules: "Capture each design decision with its rationale and the trade-offs considered.",
                openQuestionRules: "Capture unresolved design questions and who is to investigate them.",
                keyPointRules: "Capture important design principles or constraints identified, concerns raised, and their resolution.",
                additionalGuidance: attributionGuidance
            )
        case .oneOnOne:
            return PromptComponentSet(
                objective: "Summarize one-on-one discussions with clear outcomes.",
                summaryFocus: "Capture feedback themes, guidance given with its reasoning, agreements, growth/career discussion, and personal follow-up actions. Be professional and discreet.",
                decisionRules: "Capture agreements made between the two parties, with rationale.",
                actionItemRules: "Capture specific follow-ups each person committed to.",
                keyPointRules: "Capture important feedback or context shared, and who gave versus who received coaching.",
                additionalGuidance: attributionGuidance
            )
        case .presentation:
            return PromptComponentSet(
                objective: "Summarize presentation content and takeaways.",
                summaryFocus: "Capture what was presented section by section, key arguments, data and metrics shared, demos shown, Q&A highlights, and concrete next steps.",
                keyPointRules: "Capture key data points and benchmarks exactly as stated, and notable Q&A exchanges with who asked when identifiable.",
                additionalGuidance: attributionGuidance
            )
        case .planning:
            return PromptComponentSet(
                objective: "Summarize planning decisions and execution intent.",
                summaryFocus: "Capture scope, ownership, timelines, dependencies, and open risks.",
                decisionRules: "Capture scope and priority decisions with rationale.",
                actionItemRules: "Capture allocated tasks with owner and due date where stated.",
                keyPointRules: "Capture estimates, dependencies, risks, and constraints discussed.",
                additionalGuidance: attributionGuidance
            )
        case .interviewTaken:
            return PromptComponentSet(
                objective: "Summarize a job interview from the interviewer's perspective, producing an evidence-based record for the hiring debrief.",
                summaryFocus: "Capture the round type, problems or questions posed, the candidate's approach to each, follow-up probes, observed strengths and concerns with specific evidence, and the overall impression.",
                decisionRules: "Capture assessment leanings explicitly expressed (e.g. signal strength or hire/no-hire leaning); never infer one.",
                actionItemRules: "Capture follow-ups such as debrief points to raise, references to check, or next rounds to schedule.",
                openQuestionRules: "Capture unresolved doubts about the candidate and topics not covered in time.",
                keyPointRules: "Capture question-by-question highlights: what was asked, how the candidate responded, and notable strengths or weaknesses tied to specific answers.",
                additionalGuidance: attributionGuidance
            )
        case .interviewGiven:
            return PromptComponentSet(
                objective: "Summarize a job interview from the candidate's perspective, producing an honest self-review record.",
                summaryFocus: "Capture the company and round type if mentioned, each question posed, the approach taken, interviewer hints or corrections, what went well, what could improve, and learnings for next time.",
                decisionRules: "Capture concrete process conclusions, such as agreed next steps.",
                actionItemRules: "Capture follow-ups such as topics to study or practice and materials to send.",
                openQuestionRules: "Capture unanswered questions about the role, team, or process, and problems left unresolved.",
                keyPointRules: "Capture question-by-question highlights including interviewer feedback, plus interviewer style, time management, and role/team information gathered.",
                additionalGuidance: attributionGuidance
            )
        case .allHands:
            return PromptComponentSet(
                objective: "Summarize an all-hands or town-hall meeting for people who missed it.",
                summaryFocus: "Capture announcements and org updates with the speaker attributed, key messages from leadership, metrics and goals shared, and Q&A highlights.",
                decisionRules: "Capture announced changes or commitments, such as org changes or strategy shifts.",
                actionItemRules: "Capture asks made of the audience and commitments made by leadership.",
                openQuestionRules: "Capture Q&A questions that were deferred or left unanswered.",
                keyPointRules: "Capture each announcement, metrics and goals exactly as stated, and notable Q&A exchanges with who asked and who answered when identifiable.",
                additionalGuidance: attributionGuidance
            )
        case .retrospective:
            return PromptComponentSet(
                objective: "Summarize a retrospective or post-mortem with balanced, attributed findings.",
                summaryFocus: "Organize findings into what went well, what didn't go well, and what to improve, attributing who raised each item where identifiable.",
                decisionRules: "Capture agreed process changes or experiments to adopt.",
                actionItemRules: "Capture improvement actions with a committed owner; ideas without commitment belong in key points.",
                openQuestionRules: "Capture unresolved disagreements or topics parked for follow-up.",
                keyPointRules: "Capture what went well and what didn't, each with who raised it and the surrounding discussion.",
                additionalGuidance: attributionGuidance
            )
        }
    }

    private func sortDefinitions(_ definitions: [MeetingTypeDefinition]) -> [MeetingTypeDefinition] {
        let builtInOrder = Dictionary(
            uniqueKeysWithValues: MeetingType.allCases.enumerated().map { ($1.rawValue, $0) }
        )

        return definitions.sorted { lhs, rhs in
            if lhs.status != rhs.status {
                if lhs.status == .active { return true }
                if rhs.status == .active { return false }
            }

            if lhs.source != rhs.source {
                return lhs.source == .builtIn
            }

            if lhs.source == .builtIn {
                let lhsOrder = builtInOrder[lhs.typeId] ?? Int.max
                let rhsOrder = builtInOrder[rhs.typeId] ?? Int.max
                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }
            }

            let lhsName = lhs.displayName.lowercased()
            let rhsName = rhs.displayName.lowercased()
            if lhsName != rhsName {
                return lhsName < rhsName
            }

            return lhs.typeId < rhs.typeId
        }
    }
}

public enum MeetingTypeSelectionMode: String, Codable, Sendable, Equatable {
    case manual
    case autodetect
}

public enum MeetingTypeResolutionSource: String, Codable, Sendable, Equatable {
    case manual
    case classifier
    case fallbackGeneral = "fallback_general"
}

public struct MeetingTypeSelection: Codable, Sendable, Equatable {
    public var selectionMode: MeetingTypeSelectionMode
    public var selectedTypeId: String
    public var resolvedTypeId: String?
    public var resolutionSource: MeetingTypeResolutionSource?

    public init(
        selectionMode: MeetingTypeSelectionMode,
        selectedTypeId: String,
        resolvedTypeId: String? = nil,
        resolutionSource: MeetingTypeResolutionSource? = nil
    ) {
        self.selectionMode = selectionMode
        self.selectedTypeId = selectedTypeId
        self.resolvedTypeId = resolvedTypeId
        self.resolutionSource = resolutionSource
    }
}

public enum ResolvedPromptSourceKind: String, Codable, Sendable, Equatable {
    case builtInDefault = "built_in_default"
    case builtInOverride = "built_in_override"
    case custom
}

public struct ResolvedPromptBundle: Codable, Sendable, Equatable {
    public var typeId: String
    public var typeDisplayName: String
    public var systemPrompt: String
    public var userPromptPreamble: String
    public var runtimeLanguageMode: String
    public var runtimeOutputLanguage: String
    public var sourceKind: ResolvedPromptSourceKind

    public init(
        typeId: String,
        typeDisplayName: String,
        systemPrompt: String,
        userPromptPreamble: String,
        runtimeLanguageMode: String,
        runtimeOutputLanguage: String,
        sourceKind: ResolvedPromptSourceKind
    ) {
        self.typeId = typeId
        self.typeDisplayName = typeDisplayName
        self.systemPrompt = systemPrompt
        self.userPromptPreamble = userPromptPreamble
        self.runtimeLanguageMode = runtimeLanguageMode
        self.runtimeOutputLanguage = runtimeOutputLanguage
        self.sourceKind = sourceKind
    }
}
