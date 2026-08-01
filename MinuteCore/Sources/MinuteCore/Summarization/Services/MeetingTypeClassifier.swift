//
//  MeetingTypeClassifier.swift
//  MinuteCore
//
//  Created for Feature 003-meeting-type-prompts
//

import Foundation

public struct MeetingTypeClassifierCandidate: Sendable, Equatable {
    public var typeId: String
    public var label: String
    public var strongSignals: [String]

    public init(typeId: String, label: String, strongSignals: [String]) {
        self.typeId = typeId
        self.label = label
        self.strongSignals = strongSignals
    }
}

public enum MeetingTypeClassifier {

    private static let allowedOutputLabels: [String] = [
        "General",
        "Standup",
        "Design Review",
        "One-on-One",
        "Presentation",
        "Planning",
        "Interview — Taken",
        "Interview — Given",
        "All Hands",
        "Retrospective"
    ]
    
    /// Generates the prompt for the first-pass classification.
    /// - Parameter transcript: A representative snippet of the transcript (truncated by character count).
    /// - Returns: The classification prompt string.
    public static func prompt(for transcript: String) -> String {
        let maxSnippetCharacters = 3_000
        let snippet = String(transcript.prefix(maxSnippetCharacters))

        let allowedLabels = allowedOutputLabels.joined(separator: "\n- ")

        return """
        You are a strict classifier.

        Task: Choose exactly one meeting type label from the allowed list below.
        Allowed labels (return EXACTLY one of these, with no extra text):
        - \(allowedLabels)

        Conservative rule (important): If you are uncertain, the snippet is low-information, or signals are mixed, return General.

        Strong signals (choose a non-General label only when strong):
        - Standup: explicit standup/daily mention OR yesterday/today/blockers round-robin status updates.
        - One-on-One: explicit 1:1 mention OR manager↔report feedback/career check-in, personal alignment.
        - Design Review: explicit design review mention OR critique of mockups/UX/architecture proposals, tradeoffs.
        - Presentation: one-to-many talk with slides/demo, speaker-led narrative, audience Q&A.
        - Planning: sprint/roadmap planning with estimation, ticketing, owners, timelines, scope.
        - Interview — Taken: structured Q&A evaluating a candidate, with the transcript owner ASKING coding/design/behavioral questions.
        - Interview — Given: structured interview Q&A with the transcript owner ANSWERING questions and being evaluated.
        - All Hands: org-wide updates, leadership speaking to a large audience, town-hall Q&A.
        - Retrospective: explicit retro/post-mortem mention OR what-went-well / what-didn't / improvements structure.

        Default-to-General examples (low-information):
        - "Hey everyone." => General
        - "Thanks." => General
        - "Let's start." => General
        - "Any updates?" => General
        - "Sounds good." => General

        Default-to-General examples (mixed signals):
        - "We reviewed the design briefly, then planned the sprint backlog and assigned owners." => General
        - "Quick updates, then a deep design critique, then roadmap planning." => General
        - "We did a demo, then discussed timelines and tasks for next sprint." => General

        Default-to-General examples (keyword traps):
        - "We need to plan a vacation sometime." => General
        - "That presentation was great yesterday." => General
        - "One thing to note: performance improved." => General
        - "Let's review the logs later." => General

        Positive examples (clear, strong signals):
        - "Yesterday I fixed the login bug. Today I'm working on the settings screen. Blockers: none." => Standup
        - "Daily standup: what did you do yesterday, what will you do today, any blockers?" => Standup
        - "1:1 check-in: how are you feeling about your growth goals and workload?" => One-on-One
        - "Manager: I'd like to give feedback on last quarter and talk about career progression." => One-on-One
        - "Design review: let's critique this UI flow and discuss tradeoffs in the architecture proposal." => Design Review
        - "We reviewed mockups, accessibility concerns, and decided on the information hierarchy." => Design Review
        - "Today's presentation covers our new API design. We'll do a live demo, then Q&A." => Presentation
        - "In this talk, I'll walk through the slides and highlight key takeaways." => Presentation
        - "Sprint planning: estimate these tickets, assign owners, and agree on the timeline." => Planning
        - "Roadmap planning: decide milestones, dependencies, and next sprint scope." => Planning

        Output format: Return ONLY the label. No punctuation, quotes, bullets, or explanations.

        Transcript snippet:
        \(snippet)
        """
    }

    /// Generates a classifier prompt for built-in and custom candidates.
    public static func prompt(
        for transcript: String,
        candidates: [MeetingTypeClassifierCandidate],
        fallbackLabel: String
    ) -> String {
        let maxSnippetCharacters = 3_000
        let snippet = String(transcript.prefix(maxSnippetCharacters))
        let normalizedCandidates = normalizedCandidates(from: candidates)
        let labels = normalizedCandidates.map(\.label)
        let allowedLabels = labels.joined(separator: "\n- ")
        let fallback = fallbackLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateGuidance = normalizedCandidates
            .map { candidate in
                let signals = candidate.strongSignals.isEmpty
                    ? "No strong signals provided."
                    : candidate.strongSignals.map { "\"\($0)\"" }.joined(separator: ", ")
                return "- \(candidate.label): \(signals)"
            }
            .joined(separator: "\n")

        return """
        You are a strict meeting-type classifier.

        Task: Choose exactly one label from the allowed list below.
        Allowed labels (return EXACTLY one, no extra text):
        - \(allowedLabels)

        Conservative rule: if uncertain, low-information, or mixed signals, return \(fallback).

        Candidate guidance:
        \(candidateGuidance)

        Output format: return only the label, with exact spelling from allowed labels.

        Transcript snippet:
        \(snippet)
        """
    }
    
    /// Parses the LLM response into a MeetingType.
    /// - Parameter response: The raw string response from the LLM.
    /// - Returns: The determined MeetingType, defaulting to .general if ambiguous.
    public static func parseResponse(_ response: String) -> MeetingType {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()

        switch normalized {
        case "general": return .general
        case "standup": return .standup
        case "design review": return .designReview
        case "one-on-one": return .oneOnOne
        case "presentation": return .presentation
        case "planning": return .planning
        case "interview — taken", "interview - taken", "interview taken": return .interviewTaken
        case "interview — given", "interview - given", "interview given": return .interviewGiven
        case "all hands", "all hands / town hall", "town hall": return .allHands
        case "retrospective", "retro", "post-mortem", "postmortem": return .retrospective
        default: return .general
        }
    }

    public static func parseResponse(
        _ response: String,
        candidates: [MeetingTypeClassifierCandidate],
        fallbackTypeID: String
    ) -> String {
        let normalized = response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedCandidates = normalizedCandidates(from: candidates)
        let match = normalizedCandidates.first { $0.label.lowercased() == normalized }
        return match?.typeId ?? fallbackTypeID
    }

    private static func normalizedCandidates(
        from candidates: [MeetingTypeClassifierCandidate]
    ) -> [MeetingTypeClassifierCandidate] {
        var seenTypeIDs: Set<String> = []
        var seenLabels: Set<String> = []
        var result: [MeetingTypeClassifierCandidate] = []
        result.reserveCapacity(candidates.count)

        for raw in candidates {
            let typeId = raw.typeId.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = raw.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !typeId.isEmpty, !label.isEmpty else { continue }

            let typeKey = typeId.lowercased()
            let labelKey = label.lowercased()
            guard seenTypeIDs.insert(typeKey).inserted else { continue }
            guard seenLabels.insert(labelKey).inserted else { continue }

            let signals = raw.strongSignals
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            result.append(
                MeetingTypeClassifierCandidate(
                    typeId: typeId,
                    label: label,
                    strongSignals: signals
                )
            )
        }

        return result
    }
}
