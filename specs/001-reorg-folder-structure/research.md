# Research: Reorganize folder and package structure

**Feature**: Reorganize folder and package structure
**Status**: Research Validated

## Decisions Log

### 1. Folder Structure
**Decision**:
- Move all ViewModels to `Minute/ViewModels/`.
- Move all Views to `Minute/Views/` (grouping by feature).
- Move App domain types (like `MeetingPipelineTypes.swift`) to `MinuteCore/Sources/MinuteCore/domain` or `pipeline`.
- Move `Vendor/` contents to a single root `Vendor/` directory.

**Rationale**:
- Separation of concerns: App target contains UI and Composition Root; Core contains Business Logic.
- Consolidating ViewModels makes the UI layer structure obvious.
- Single Vendor directory simplifies dependency tracking.

### 2. Package Changes (`MinuteCore`)
**Decision**:
- Update `Package.swift` to reference `Vendor/` via relative paths (`../Vendor`) or symlink if SwiftPM requires it to be inside the package folder.
- *Correction*: SwiftPM binary targets *must* be inside the package directory or a remote URL. They cannot represent a path outside the package root easily without local package replacement or symlinks.
- **Revised Decision**: Keep `llama` and `whisper` frameworks inside `MinuteCore/Vendor/` to ensure `Package.swift` works without friction. The root `Vendor/` can contain `ffmpeg` (which is likely bundled by script, not `Package.swift`).

**Rationale**:
- SwiftPM `binaryTarget` path restriction.

### 3. Minute.xcodeproj Updates
**Decision**:
- Use "Option A" (In-place updates).
- Manually edit or use `sed` / `xcodebuild` / tooling to update file references.
- Since we are moving files on disk, we must update the project file.

### 4. Module Renaming
**Decision**:
- "Option B" from Spec: Rename modules if necessary.
- Currently `MinuteCore` is well named.
- `MinuteWhisperService` is well named.
- No major module renaming required, just organization within the targets.

## Migration Strategy

1.  **Phase 1: MinuteCore Cleanup**
    - Move `MeetingPipelineTypes.swift` to `MinuteCore`.
    - Verify `MinuteCore` builds.

2.  **Phase 2: UI Reorg**
    - Create `Minute/ViewModels`, `Minute/Views`.
    - Move files.
    - Update Xcode Project references (batch update).

3.  **Phase 3: Root Cleanup**
    - Consolidate Scripts? (Already in `scripts/`).
    - Verify `MinuteWhisperService`.

## Open Questions Resolved

- **Q: Where does `MinuteWhisperService` go?**
  - A: Keep at root (or `Services/` root). It is a standalone top-level target.

- **Q: `Vendor` location?**
  - A: `MinuteCore` deps stay in `MinuteCore/Vendor` (technically). `ffmpeg` stays in root `Vendor` (or move to `Vendor` if not there).
  - *Actually*, `MinuteCore` `binaryTarget` paths are relative to package root. So `MinuteCore/Vendor` is required for those.
  - We will clarify "Vendor" structure: `MinuteCore/Vendor` for Package deps, `Vendor/` for App deps (ffmpeg).

