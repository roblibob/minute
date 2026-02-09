# Implementation Plan: UI Layout Fixes

**Branch**: `007-fix-ui-layout` | **Date**: 2026-02-09 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/007-fix-ui-layout/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Fix two critical UI layout bugs in the Minute macOS app:
1. **Meeting list viewport overflow**: Meeting history list extends beyond visible viewport due to incorrect SwiftUI layout constraints
2. **Meeting type selector positioning**: Meeting type dropdown obscured by record button in the main recording control bar
3. **Control bar width optimization**: Expand control bar to utilize 70%+ of content area width

**Technical Approach**: Use Swift + SwiftUI native layout system to adjust constraints and spacing:
- Fix `MeetingNotesSidebarView` constraints to prevent overflow and ensure proper clipping
- Adjust `FloatingControlBar` layout in `ContentView.swift` to increase width and prevent control overlap
- Enforce minimum window size (600x400) and ensure responsive layout across window sizes

## Technical Context

**Language/Version**: Swift 5.9+ (Xcode 15.x), SwiftUI  
**Primary Dependencies**: SwiftUI, AppKit (for macOS window management), MinuteCore (domain logic)  
**Storage**: N/A (UI layout fixes only)  
**Testing**: Swift Testing (MinuteCore), Manual QA on target hardware  
**Target Platform**: macOS 14+ (macOS 15.7.3 specifically affected)
**Project Type**: Native macOS desktop application  
**Performance Goals**: Maintain 60fps UI responsiveness, no layout-induced performance degradation  
**Constraints**: 
- UI changes must not affect audio/transcription pipeline
- Changes must be backward compatible with macOS 14+
- Must preserve existing design language and visual style
- Minimum window size: 600x400 pixels
- Control bar must span 70%+ of content area width
**Scale/Scope**: 2 view files affected (`ContentView.swift`, `MeetingNotesSidebarView.swift`), ~200 lines modified

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Initial Check (Pre-Phase 0)
- ✅ **Output contract unchanged**: UI layout fixes do not affect the three-file output contract (meeting notes, audio, transcripts). No path changes, no rendering changes.
- ✅ **Local-only processing preserved**: No network calls involved. UI-only changes.
- ✅ **Deterministic Markdown rendering maintained**: No changes to note rendering or Markdown generation.
- ✅ **MinuteCore tests**: Not applicable - this is a pure UI layout fix in the Minute app target. No MinuteCore logic affected.
- ✅ **Pipeline state machine respected**: Layout changes do not affect pipeline state transitions, cancellation, or long-running operations.
- ✅ **No constitution violations**: This is a straightforward UI bug fix that aligns with Principle IV (Consistent, Predictable UX).

**Initial Gate Status**: ✅ **PASSED** - No violations. Proceed to Phase 0.

### Post-Design Check (After Phase 1)
- ✅ **Output contract unchanged**: Confirmed - only SwiftUI view layout modifiers affected. No file paths, no Markdown rendering, no vault output changes.
- ✅ **Local-only processing preserved**: Confirmed - zero network code involved.
- ✅ **Deterministic Markdown rendering maintained**: Confirmed - no changes to MinuteCore rendering logic.
- ✅ **MinuteCore tests**: Confirmed N/A - changes are exclusively in `Minute/Sources/Views/` (ContentView.swift, MeetingNotesSidebarView.swift).
- ✅ **Pipeline state machine respected**: Confirmed - no changes to MeetingPipelineViewModel or state transitions.
- ✅ **TDD requirement**: Not applicable per constitution - MinuteCore tests required only for business logic. UI layout fixes verified through manual QA.
- ✅ **Performance and responsiveness**: Layout changes use standard SwiftUI modifiers with no performance impact. 60fps maintained.
- ✅ **SOLID principles**: Not applicable - no new types or abstractions. Pure declarative UI adjustments.

**Final Gate Status**: ✅ **PASSED** - Design complete. No constitution violations. Ready for implementation (Phase 2 tasks).

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
Minute/
├── Sources/
│   └── Views/
│       ├── ContentView.swift                    # UPDATE: Fix FloatingControlBar layout
│       └── MeetingNotes/
│           └── MeetingNotesSidebarView.swift   # UPDATE: Fix List constraints
├── Config/
│   └── MinuteInfo.plist                        # UPDATE: Add minimum window size (if needed)

# No MinuteCore changes - pure UI layout fix
```

**Structure Decision**: Single project structure. All changes are in the `Minute/` app target within existing view files. No new files required, no MinuteCore changes.
