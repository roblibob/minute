import Foundation
import MinuteCore
import Testing
@testable import Minute

@MainActor
struct MeetingNotesBrowserViewModelReprocessingTests {
    @Test
    func availableReprocessTargets_excludesOnlyAutodetect() async throws {
        let item = ReprocessMeetingBrowserTestSupport.makeMeetingItem(
            hasTranscript: true,
            currentMeetingTypeId: MeetingType.general.rawValue
        )
        let browser = ReprocessingBrowserStub(notes: [item], noteByID: [item.id: "# Product Review"], transcriptByID: [item.id: "Speaker 1 [00:00]\nHello"])
        let store = MockMeetingTypeLibraryStore()
        let model = MeetingNotesBrowserViewModel(
            browserProvider: { browser },
            meetingTypeLibraryStore: store
        )

        let targets = model.availableReprocessTargetTypes(for: item).map(\.typeId)

        #expect(!targets.contains(MeetingType.autodetect.rawValue))
        #expect(targets.contains(MeetingType.general.rawValue))
        #expect(targets.contains(MeetingType.planning.rawValue))
    }

    @Test
    func prepareReprocess_allowsCurrentMeetingTypeSelection() {
        let item = ReprocessMeetingBrowserTestSupport.makeMeetingItem(
            hasTranscript: true,
            currentMeetingTypeId: MeetingType.general.rawValue
        )
        let browser = ReprocessingBrowserStub(notes: [item], noteByID: [:], transcriptByID: [:])
        let store = MockMeetingTypeLibraryStore()
        let model = MeetingNotesBrowserViewModel(
            browserProvider: { browser },
            meetingTypeLibraryStore: store,
            reprocessRunner: { _ in
                Issue.record("Reprocess runner should not be invoked while only staging confirmation.")
                return PipelineResult(noteURL: item.fileURL, audioURL: nil)
            }
        )

        model.prepareReprocess(for: item, targetTypeID: MeetingType.general.rawValue)

        #expect(model.pendingReprocessSelection?.meetingId == item.id)
        #expect(model.pendingReprocessSelection?.targetMeetingTypeId == MeetingType.general.rawValue)
        #expect(model.pendingReprocessSelection?.targetMeetingTypeDisplayName == MeetingType.general.displayName)
    }

    @Test
    func reprocessAvailability_blocksWhenTranscriptIsMissing() {
        let item = ReprocessMeetingBrowserTestSupport.makeMeetingItem(hasTranscript: false)
        let browser = ReprocessingBrowserStub(notes: [item], noteByID: [:], transcriptByID: [:])
        let model = MeetingNotesBrowserViewModel(browserProvider: { browser })

        let availability = model.reprocessAvailability(for: item)

        #expect(availability.canReprocess == false)
        #expect(availability.blockingReason == .missingTranscript)
    }

    @Test
    func prepareReprocess_stagesExplicitTargetConfirmation() {
        let item = ReprocessMeetingBrowserTestSupport.makeMeetingItem(
            hasTranscript: true,
            currentMeetingTypeId: MeetingType.general.rawValue
        )
        let browser = ReprocessingBrowserStub(notes: [item], noteByID: [:], transcriptByID: [:])
        let store = MockMeetingTypeLibraryStore()
        let model = MeetingNotesBrowserViewModel(
            browserProvider: { browser },
            meetingTypeLibraryStore: store,
            reprocessRunner: { _ in
                Issue.record("Reprocess runner should not be invoked while only staging confirmation.")
                return PipelineResult(noteURL: item.fileURL, audioURL: nil)
            }
        )

        model.prepareReprocess(for: item, targetTypeID: MeetingType.planning.rawValue)

        #expect(model.pendingReprocessSelection?.meetingId == item.id)
        #expect(model.pendingReprocessSelection?.targetMeetingTypeId == MeetingType.planning.rawValue)
        #expect(model.pendingReprocessSelection?.targetMeetingTypeDisplayName == MeetingType.planning.displayName)
    }

    @Test
    func reprocessAvailability_reportsUnreadableTranscriptBlockingReason() {
        let item = ReprocessMeetingBrowserTestSupport.makeMeetingItem(
            hasTranscript: false,
            reprocessBlockingReason: .unreadableTranscript
        )
        let browser = ReprocessingBrowserStub(notes: [item], noteByID: [:], transcriptByID: [:])
        let model = MeetingNotesBrowserViewModel(browserProvider: { browser })

        let availability = model.reprocessAvailability(for: item)

        #expect(availability.canReprocess == false)
        #expect(availability.blockingReason == .unreadableTranscript)
        #expect(model.reprocessDisabledReason(for: item) == "Transcript file is unreadable, so resummarization is unavailable.")
    }

    @Test
    func cancelPendingReprocess_clearsConfirmationWithoutRunningReprocess() {
        let item = ReprocessMeetingBrowserTestSupport.makeMeetingItem(
            hasTranscript: true,
            currentMeetingTypeId: MeetingType.general.rawValue
        )
        let browser = ReprocessingBrowserStub(notes: [item], noteByID: [:], transcriptByID: [:])
        let store = MockMeetingTypeLibraryStore()
        let model = MeetingNotesBrowserViewModel(
            browserProvider: { browser },
            meetingTypeLibraryStore: store,
            reprocessRunner: { _ in
                Issue.record("Reprocess runner should not be invoked after cancel.")
                return PipelineResult(noteURL: item.fileURL, audioURL: nil)
            }
        )

        model.prepareReprocess(for: item, targetTypeID: MeetingType.planning.rawValue)
        model.cancelPendingReprocess()

        #expect(model.pendingReprocessSelection == nil)
    }
}

private actor ReprocessingBrowserStub: MeetingNotesBrowsing {
    private let notes: [MeetingNoteItem]
    private let noteByID: [String: String]
    private let transcriptByID: [String: String]

    init(notes: [MeetingNoteItem], noteByID: [String: String], transcriptByID: [String: String]) {
        self.notes = notes
        self.noteByID = noteByID
        self.transcriptByID = transcriptByID
    }

    func listNotes() async throws -> [MeetingNoteItem] { notes }
    func loadNoteContent(for item: MeetingNoteItem) async throws -> String { noteByID[item.id] ?? "" }
    func loadTranscriptContent(for item: MeetingNoteItem) async throws -> String { transcriptByID[item.id] ?? "" }
    func deleteNoteFiles(for item: MeetingNoteItem) async throws { _ = item }

    func renameNoteFiles(for item: MeetingNoteItem, to newTitle: String) async throws -> MeetingNoteItem {
        _ = newTitle
        return item
    }
}

private final class MockMeetingTypeLibraryStore: MeetingTypeLibraryStoring, @unchecked Sendable {
    private let library = MeetingTypeLibrary.default

    func load() -> MeetingTypeLibrary { library }
    func save(_ library: MeetingTypeLibrary) { _ = library }
    @discardableResult
    func saveValidated(_ library: MeetingTypeLibrary) throws -> MeetingTypeLibrary { library }
    func clear() {}
}