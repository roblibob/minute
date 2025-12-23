# Markdown Viewing Solution Design

## Goal
Provide a sidebar in the main UI that lists Markdown notes in the configured meetings folder, and show a read-only Markdown preview in an overlay on top of the main window when a note is selected.

## Non-goals
- Minute is not a Markdown editor.
- Do not change the output contract or note format.
- Do not read or display transcripts unless explicitly selected from the meetings folder list.
- No outbound network calls beyond model downloads.

## Constraints (from AGENT.md and docs)
- macOS 14+ native app (SwiftUI).
- Vault access must use security-scoped bookmarks.
- UI stays thin; business logic lives in MinuteCore when practical.
- Do not log raw note content by default.

## Proposed Architecture
Add a small MinuteCore service for listing and loading meeting notes, plus a UI overlay that renders Markdown using `swift-markdown-ui`.

### New MinuteCore Types
```
struct MeetingNoteItem: Sendable, Identifiable {
    var id: String            // relative path
    var title: String
    var date: Date?
    var relativePath: String
    var fileURL: URL
}

protocol MeetingNotesBrowsing: Sendable {
    func listNotes() async throws -> [MeetingNoteItem]
    func loadNoteContent(for item: MeetingNoteItem) async throws -> String
}
```

### New MinuteCore Service
- `VaultMeetingNotesBrowser` (MinuteCore)
  - Depends on `VaultAccess` and `VaultConfiguration`.
  - Uses `VaultAccess.withVaultAccess` to:
    - Locate the meetings root using `meetingsRelativePath`.
    - Recursively enumerate Markdown files (`.md`) under that folder.
    - Exclude `_audio` and `_transcripts` directories to avoid showing non-note artifacts.
  - Parses `YYYY-MM-DD HH:MM - Title.md` from filenames to derive `title` and `date`.
  - Sorts newest-first by parsed date; falls back to file modification date when parsing fails.
  - Reads file contents as UTF-8 and returns a `String`.

### New UI Components (Minute target)
- `MeetingNotesSidebarView`
  - A sidebar `List` bound to `MeetingNotesBrowserViewModel`.
  - Shows date + title; supports refresh when pipeline completes.
- `MarkdownViewerOverlay`
  - A `ZStack` overlay with dimmed background and a card-style container.
  - Uses `MarkdownUI.Markdown` to render content.
  - Includes a Close button and supports Escape to dismiss.

### State + Flow
1. On appear, the view model calls `MeetingNotesBrowsing.listNotes()`.
2. Selecting an item triggers `loadNoteContent`, shows overlay once content is loaded.
3. When the pipeline finishes writing a new note, call `listNotes()` again so the sidebar updates.
4. Overlay dismissal clears the currently selected item and content.

### Dependency Integration
- Add `swift-markdown-ui` to the Minute target via Swift Package Manager.
- Keep rendering inside the UI layer; do not add the dependency to MinuteCore.

## Error Handling
- If vault access fails, show an inline sidebar error state and a retry action.
- If file read fails, show a concise error message in the overlay with a retry option.
- If Markdown parsing fails, fallback to rendering raw text in a `ScrollView`.

## Testing Plan
- Unit tests (MinuteCore):
  - File enumeration excludes `_audio` and `_transcripts`.
  - Filename parsing and sort order.
  - Fallback to file modification date on parse failure.
- Manual QA:
  - Sidebar lists notes under `Meetings/YYYY/MM`.
  - Selecting a note shows the overlay and renders Markdown correctly.
  - New note appears after processing completes.
  - Vault not configured shows a clear error.

## Risks and Mitigations
- Large notes may be slow to load: read asynchronously and allow cancellation.
- Security-scoped access lifetime: wrap each listing/read in `withVaultAccess`.
- UI clutter: keep overlay minimal and dismissible to preserve the primary pipeline UI.

## Open Questions
- Should transcript files in `_transcripts` ever be surfaced as a separate toggle?
- Should the overlay support quick navigation (Next/Previous) within the list?
