import Foundation
import MinuteCore
import Testing
@testable import Minute

@MainActor
struct MeetingDetailNoRegressionSmokeTests {
    @Test
    func selectMeeting_showsOverlay_andLoadsSummary() async throws {
        let item = MeetingNoteItem(
            title: "Test Meeting",
            date: Date(timeIntervalSince1970: 0),
            relativePath: "Meetings/2026/02/2026-02-10 09.00 - Test Meeting.md",
            fileURL: URL(fileURLWithPath: "/tmp/Test Meeting.md"),
            hasTranscript: false,
            transcriptURL: nil
        )

        let browser = MockMeetingNotesBrowser(
            notes: [item],
            noteContent: "# Summary\n\nHello",
            transcriptContent: ""
        )

        let model = MeetingNotesBrowserViewModel(browserProvider: { browser })

        model.refresh()

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                model.isRefreshing == false && model.notes == [item]
            }
        }

        model.select(item)

        #expect(model.isOverlayPresented == true)
        #expect(model.selectedItem == item)
        #expect(model.selectedTab == .summary)

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                model.isLoadingContent == false && model.noteContent == "# Summary\n\nHello"
            }
        }

        model.dismissOverlay()
        #expect(model.isOverlayPresented == false)
        #expect(model.selectedItem == nil)
    }
}

private actor MockMeetingNotesBrowser: MeetingNotesBrowsing {
    private let notes: [MeetingNoteItem]
    private let noteContent: String
    private let transcriptContent: String

    init(notes: [MeetingNoteItem], noteContent: String, transcriptContent: String) {
        self.notes = notes
        self.noteContent = noteContent
        self.transcriptContent = transcriptContent
    }

    func listNotes() async throws -> [MeetingNoteItem] {
        notes
    }

    func loadNoteContent(for item: MeetingNoteItem) async throws -> String {
        _ = item
        return noteContent
    }

    func loadTranscriptContent(for item: MeetingNoteItem) async throws -> String {
        _ = item
        return transcriptContent
    }

    func deleteNoteFiles(for item: MeetingNoteItem) async throws {
        _ = item
    }
}

private func eventually(
    timeoutNanoseconds: UInt64,
    pollIntervalNanoseconds: UInt64 = 10_000_000,
    condition: @escaping @Sendable () async -> Bool
) async throws {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    while DispatchTime.now().uptimeNanoseconds < deadline {
        if await condition() {
            return
        }
        try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
    }

    throw TestTimeoutError()
}

private struct TestTimeoutError: Error {}
