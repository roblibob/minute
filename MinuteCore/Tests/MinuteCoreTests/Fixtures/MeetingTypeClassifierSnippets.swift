import Foundation

enum MeetingTypeClassifierSnippets {
    static let lowInformation: [String] = [
        "Hey everyone.",
        "Thanks.",
        "Let's start.",
        "Any updates?",
        "Sounds good."
    ]

    static let mixedSignals: [String] = [
        "We reviewed the design briefly, then planned the sprint backlog and assigned owners.",
        "Quick updates, then a deep design critique, then roadmap planning.",
        "We did a demo, then discussed timelines and tasks for next sprint."
    ]

    static let keywordTraps: [String] = [
        "We need to plan a vacation sometime.",
        "That presentation was great yesterday.",
        "One thing to note: performance improved.",
        "Let's review the logs later."
    ]

    static let clearStandup: [String] = [
        "Yesterday I fixed the login bug. Today I'm working on the settings screen. Blockers: none.",
        "Daily standup: what did you do yesterday, what will you do today, any blockers?"
    ]

    static let clearOneOnOne: [String] = [
        "1:1 check-in: how are you feeling about your growth goals and workload?",
        "Manager: I'd like to give feedback on last quarter and talk about career progression."
    ]

    static let clearDesignReview: [String] = [
        "Design review: let's critique this UI flow and discuss tradeoffs in the architecture proposal.",
        "We reviewed mockups, accessibility concerns, and decided on the information hierarchy."
    ]

    static let clearPresentation: [String] = [
        "Today's presentation covers our new API design. We'll do a live demo, then Q&A.",
        "In this talk, I'll walk through the slides and highlight key takeaways."
    ]

    static let clearPlanning: [String] = [
        "Sprint planning: estimate these tickets, assign owners, and agree on the timeline.",
        "Roadmap planning: decide milestones, dependencies, and next sprint scope."
    ]
}
