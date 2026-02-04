# Tasks: Reorganize folder and package structure

**Branch**: `001-reorg-folder-structure` | **Spec**: [specs/001-reorg-folder-structure/spec.md](specs/001-reorg-folder-structure/spec.md)
**Status**: Generated

## Phase 1: Setup & Validation (Foundational)

- [x] T001 [Setup] Verify `Minute.xcodeproj` builds successfully before changes
- [x] T002 [Setup] Verify `MinuteCore` tests pass before changes

## Phase 2: MinuteCore Consolidation (User Story 1 & 2)

**Goal**: Move non-UI business logic and services into the `MinuteCore` package to enforce the "thin UI" architecture.

- [x] T003 [US1] Create `MinuteCore/Sources/MinuteCore/Domain` directory
- [x] T004 [US1] Move `Minute/Pipeline/MeetingPipelineTypes.swift` to `MinuteCore/Sources/MinuteCore/Domain/`
- [x] T005 [US1] Move `Minute/Services/*` to `MinuteCore/Sources/MinuteCore/Services/`
- [x] T006 [P] [US1] Update `MinuteCore/Sources/MinuteCore/Services/` file imports (add `import MinuteCore`, public modifiers)
- [x] T007 [US2] Register new files in `MinuteCore/package.swift` (if not auto-discovered) and ensure `MinuteCore` builds
- [x] T008 [US2] Update `Minute.xcodeproj` to remove references to moved Service files (they are now in the package)

## Phase 3: App Target Reorganization (User Story 1 - Build & Run)

**Goal**: Organize the `Minute` app target into clear functional folders (`Views`, `ViewModels`, `App`).

- [x] T009 [US1] Create `Minute/Sources/Views`
- [x] T010 [US1] Create `Minute/Sources/ViewModels`
- [x] T011 [US1] Create `Minute/Sources/App`
- [x] T012 [P] [US1] Move `MinuteApp.swift`, `Minute.entitlements` to `Minute/Sources/App/`
- [x] T013 [P] [US1] Move `ContentView.swift`, `CheckForUpdatesView.swift`, `ScreenContextRecordingPickerView.swift` to `Minute/Sources/Views/`
- [x] T014 [P] [US1] Move `Settings/*`, `MeetingNotes/*`, `Onboarding/*` contents to `Minute/Sources/Views/` (group by feature)
- [x] T015 [P] [US1] Move `MeetingPipelineViewModel.swift`, `UpdaterViewModel.swift` to `Minute/Sources/ViewModels/`
- [x] T016 [US1] Update `Minute.xcodeproj` groups and file references to match new locations
- [x] T017 [US1] Verify App builds and runs

## Phase 4: Vendor & Root Cleanup (User Story 3 - Discoverability)

**Goal**: Standardize vendor dependencies and consistent root layout.

- [x] T018 [US3] Ensure `Vendor/ffmpeg` exists at root (relocate if inside `Minute/Vendor`)
- [x] T019 [US3] Verify `MinuteCore/Vendor` contains `llama` and `whisper`
- [x] T020 [US3] Update `Package.swift` paths if any assumptions changed
- [x] T021 [US3] Update build scripts in `scripts/` to reflect new `Minute.xcodeproj` paths (if changed)

## Phase 5: Documentation & Polish (User Story 3)

- [x] T022 [US3] Update `README.md` with new project structure diagram
- [x] T023 [US3] Create/Update `CONTRIBUTING.md` with guide on module boundaries
- [x] T024 [P] [US3] Run full test suite (App + Core) and Fix any lingering import issues

## Dependencies

- Phase 2 must complete before Phase 3 to avoid confusing project file updates.
- Phase 3 is the largest risk for `.pbxproj` conflicts.

## Parallel Execution

- T006 (Code mods in Core) can happen parallel to T012-T015 (File moves in App), but T008/T016 (Project updates) must happen sequentially after moves.
