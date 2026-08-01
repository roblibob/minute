import Foundation
import Testing
@testable import MinuteCore

/// Tests for the enriched extraction schema: participants, topics, and
/// action-item table fields (due date, status, comments), ported from
/// field-tested meeting-notes templates.
struct MeetingExtractionRichFieldsTests {

    // MARK: - Decoding

    @Test
    func decode_richFields_present() throws {
        let json = """
        {
          "title": "Sync",
          "date": "2026-08-01",
          "summary": "s",
          "participants": [
            {"name": "Alice", "role": "Manager"},
            {"name": "Speaker 2"}
          ],
          "topics": [
            {"title": "On-call load", "points": ["Sev-2s mis-labelled", "Queue growing"]}
          ],
          "action_items": [
            {"owner": "Bob", "task": "Send changelog", "due_date": "2026-08-05", "status": "Not Started", "comments": "Needed for packaging"}
          ]
        }
        """
        let extraction = try JSONDecoder().decode(MeetingExtraction.self, from: Data(json.utf8))

        #expect(extraction.participants == [
            MeetingParticipant(name: "Alice", role: "Manager"),
            MeetingParticipant(name: "Speaker 2", role: nil),
        ])
        #expect(extraction.topics == [
            MeetingTopic(title: "On-call load", points: ["Sev-2s mis-labelled", "Queue growing"]),
        ])
        let item = try #require(extraction.actionItems.first)
        #expect(item.dueDate == "2026-08-05")
        #expect(item.status == "Not Started")
        #expect(item.comments == "Needed for packaging")
    }

    @Test
    func decode_richFields_absent_defaultsToEmpty() throws {
        let json = """
        {"title": "Sync", "date": "2026-08-01", "summary": "s", "action_items": [{"owner": "Bob", "task": "T"}]}
        """
        let extraction = try JSONDecoder().decode(MeetingExtraction.self, from: Data(json.utf8))

        #expect(extraction.participants.isEmpty)
        #expect(extraction.topics.isEmpty)
        let item = try #require(extraction.actionItems.first)
        #expect(item.dueDate == nil)
        #expect(item.status == nil)
        #expect(item.comments == nil)
    }

    @Test
    func decode_passDelta_richFields() throws {
        let json = """
        {
          "summary_points": ["p"],
          "participants": [{"name": "Alice", "role": "Manager"}],
          "topics": [{"title": "T1", "points": ["a"]}]
        }
        """
        let delta = try JSONDecoder().decode(SummarizationPassDelta.self, from: Data(json.utf8))
        #expect(delta.participants.count == 1)
        #expect(delta.topics.count == 1)
    }

    // MARK: - Validation

    @Test
    func validation_dropsEmptyParticipantsAndTopics() {
        let extraction = MeetingExtraction(
            title: "T",
            date: "2026-08-01",
            summary: "s",
            participants: [
                MeetingParticipant(name: "  Alice  ", role: "  Manager "),
                MeetingParticipant(name: "   ", role: "Ghost"),
            ],
            topics: [
                MeetingTopic(title: " Topic ", points: [" a ", "  "]),
                MeetingTopic(title: "  ", points: ["orphan"]),
            ]
        )

        let validated = MeetingExtractionValidation.validated(extraction, recordingDate: Date())
        #expect(validated.participants == [MeetingParticipant(name: "Alice", role: "Manager")])
        #expect(validated.topics == [MeetingTopic(title: "Topic", points: ["a"])])
    }

    // MARK: - Rendering

    @Test
    func render_participantsAndTopics_sectionsInTemplateOrder() throws {
        let extraction = MeetingExtraction(
            title: "Weekly Sync",
            date: "2025-12-19",
            summary: "We aligned on next steps.",
            decisions: ["Ship v1"],
            keyPoints: ["Local-only processing"],
            participants: [
                MeetingParticipant(name: "Alice", role: "Manager"),
                MeetingParticipant(name: "Speaker 2", role: nil),
            ],
            topics: [
                MeetingTopic(title: "Release plan", points: ["Ship Friday", "Bob owns packaging"]),
                MeetingTopic(title: "Docs", points: ["Decide next week"]),
            ]
        )

        let markdown = MarkdownRenderer().render(
            extraction: extraction,
            noteDateTime: "2025-12-19 09:00",
            audioDurationSeconds: nil,
            audioRelativePath: nil,
            transcriptRelativePath: nil
        )

        #expect(markdown.contains("""
        ## Participants
        - **Alice** — Manager
        - **Speaker 2**
        """))
        #expect(markdown.contains("""
        ## Topics Discussed

        ### 1. Release plan
        - Ship Friday
        - Bob owns packaging

        ### 2. Docs
        - Decide next week
        """))

        // Template order: Participants before Summary; Topics after Summary, before Decisions.
        let participantsIndex = try #require(markdown.range(of: "## Participants")).lowerBound
        let summaryIndex = try #require(markdown.range(of: "## Summary")).lowerBound
        let topicsIndex = try #require(markdown.range(of: "## Topics Discussed")).lowerBound
        let decisionsIndex = try #require(markdown.range(of: "## Decisions")).lowerBound
        #expect(participantsIndex < summaryIndex)
        #expect(summaryIndex < topicsIndex)
        #expect(topicsIndex < decisionsIndex)
    }

    @Test
    func render_withoutRichFields_omitsSectionsAndKeepsLegacyActionList() {
        let extraction = MeetingExtraction(
            title: "Weekly Sync",
            date: "2025-12-19",
            summary: "s",
            actionItems: [ActionItem(owner: "Alex", task: "Draft release notes")]
        )

        let markdown = MarkdownRenderer().render(
            extraction: extraction,
            noteDateTime: "2025-12-19 09:00",
            audioDurationSeconds: nil,
            audioRelativePath: nil,
            transcriptRelativePath: nil
        )

        #expect(!markdown.contains("## Participants"))
        #expect(!markdown.contains("## Topics Discussed"))
        #expect(markdown.contains("- [ ] Draft release notes (Owner: Alex)"))
        #expect(!markdown.contains("| # | Action |"))
    }

    @Test
    func render_actionItemsWithTableFields_rendersTable() {
        let extraction = MeetingExtraction(
            title: "Weekly Sync",
            date: "2025-12-19",
            summary: "s",
            actionItems: [
                ActionItem(owner: "Bob", task: "Send changelog", dueDate: "2026-08-05", status: "Not Started", comments: "Needed | for packaging"),
                ActionItem(owner: "Alice", task: "Review docs"),
            ]
        )

        let markdown = MarkdownRenderer().render(
            extraction: extraction,
            noteDateTime: "2025-12-19 09:00",
            audioDurationSeconds: nil,
            audioRelativePath: nil,
            transcriptRelativePath: nil
        )

        #expect(markdown.contains("| # | Action | Owner | Due Date | Status | Comments |"))
        #expect(markdown.contains("| 1 | Send changelog | Bob | 2026-08-05 | Not Started | Needed \\| for packaging |"))
        // Items without table fields get defaults in the table.
        #expect(markdown.contains("| 2 | Review docs | Alice | TBD | Not Started |  |"))
        #expect(!markdown.contains("- [ ]"))
    }

    // MARK: - Merging

    @Test
    func decode_participantSpeakerAndDetails() throws {
        let json = """
        {
          "title": "T", "date": "2026-08-01", "summary": "s",
          "participants": [
            {"name": "Jitendra", "speaker": "Speaker 2", "role": "Senior SDE", "details": "Addressed as 'Jitiva' at [02:14]; owns Matter M2."}
          ]
        }
        """
        let extraction = try JSONDecoder().decode(MeetingExtraction.self, from: Data(json.utf8))
        let participant = try #require(extraction.participants.first)
        #expect(participant.speaker == "Speaker 2")
        #expect(participant.details == "Addressed as 'Jitiva' at [02:14]; owns Matter M2.")
    }

    @Test
    func participantLine_composesNameSpeakerRoleAndDetails() {
        let full = MeetingParticipant(
            name: "Jitendra",
            role: "Senior SDE",
            speaker: "Speaker 2",
            details: "Addressed as 'Jitiva' at [02:14]; owns Matter M2."
        )
        #expect(MarkdownRenderer.participantLine(full)
            == "- **Jitendra** (Speaker 2) — Senior SDE. Addressed as 'Jitiva' at [02:14]; owns Matter M2.")

        // Speaker label collapses when it matches the name (unresolved speaker).
        let unresolved = MeetingParticipant(
            name: "Speaker 3",
            role: nil,
            speaker: "Speaker 3",
            details: "Brief closing thanks only; not part of the discussion."
        )
        #expect(MarkdownRenderer.participantLine(unresolved)
            == "- **Speaker 3** — Brief closing thanks only; not part of the discussion.")

        // Details without role.
        let detailsOnly = MeetingParticipant(name: "Manager", role: nil, speaker: "Speaker 1", details: "Says 'my team'; assigns goals.")
        #expect(MarkdownRenderer.participantLine(detailsOnly)
            == "- **Manager** (Speaker 1) — Says 'my team'; assigns goals.")
    }

    @Test
    func merger_backfillsSpeakerAndDetailsAcrossPasses() {
        let first = SummarizationPassDelta(
            summaryPoints: ["a"],
            participants: [MeetingParticipant(name: "Alice", role: nil, speaker: nil, details: nil)]
        )
        let second = SummarizationPassDelta(
            summaryPoints: ["b"],
            participants: [
                MeetingParticipant(name: "alice", role: "Manager", speaker: "Speaker 1", details: "Assigns goals; addressed by name at [10:02]."),
            ]
        )

        let state1 = SummarizationSummaryMerger.merge(previousState: nil, delta: first, meetingType: nil, recordingDate: Date())
        let state2 = SummarizationSummaryMerger.merge(previousState: state1, delta: second, meetingType: nil, recordingDate: Date())

        #expect(state2.participants.count == 1)
        #expect(state2.participants.first?.speaker == "Speaker 1")
        #expect(state2.participants.first?.details == "Assigns goals; addressed by name at [10:02].")
    }

    @Test
    func merger_mergesParticipantsAndTopicsAcrossPasses() {
        let first = SummarizationPassDelta(
            summaryPoints: ["a"],
            participants: [MeetingParticipant(name: "Alice", role: nil)],
            topics: [MeetingTopic(title: "Release plan", points: ["Ship Friday"])]
        )
        let second = SummarizationPassDelta(
            summaryPoints: ["b"],
            participants: [
                MeetingParticipant(name: "alice", role: "Manager"),
                MeetingParticipant(name: "Bob", role: nil),
            ],
            topics: [
                MeetingTopic(title: "Release Plan", points: ["Bob owns packaging"]),
                MeetingTopic(title: "Docs", points: ["Decide next week"]),
            ]
        )

        let state1 = SummarizationSummaryMerger.merge(
            previousState: nil, delta: first, meetingType: nil, recordingDate: Date()
        )
        let state2 = SummarizationSummaryMerger.merge(
            previousState: state1, delta: second, meetingType: nil, recordingDate: Date()
        )

        // Alice deduped case-insensitively, role backfilled; Bob appended.
        #expect(state2.participants.count == 2)
        #expect(state2.participants.first?.role == "Manager")
        // Topics deduped by title; points merged; Docs appended.
        #expect(state2.topics.count == 2)
        #expect(state2.topics.first?.points == ["Ship Friday", "Bob owns packaging"])
    }

    @Test
    func merger_extractionRoundTrip_carriesRichFields() {
        let delta = SummarizationPassDelta(
            title: "T",
            date: "2026-08-01",
            summaryPoints: ["s"],
            actionItems: [ActionItem(owner: "Bob", task: "Task", dueDate: "2026-08-05", status: "Not Started", comments: "c")],
            participants: [MeetingParticipant(name: "Alice", role: "Manager")],
            topics: [MeetingTopic(title: "Topic", points: ["p"])]
        )
        let state = SummarizationSummaryMerger.merge(
            previousState: nil, delta: delta, meetingType: nil, recordingDate: Date()
        )
        let extraction = SummarizationSummaryMerger.extraction(from: state, recordingDate: Date())

        #expect(extraction.participants == [MeetingParticipant(name: "Alice", role: "Manager")])
        #expect(extraction.topics == [MeetingTopic(title: "Topic", points: ["p"])])
        #expect(extraction.actionItems.first?.dueDate == "2026-08-05")
    }
}
