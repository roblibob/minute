# Tasks: UI Layout Fixes (007)

**Input**: Design documents from `/specs/007-fix-ui-layout/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓, quickstart.md ✓

**Tests**: Tests are NOT REQUIRED per constitution - this is a pure UI layout fix in the Minute app target. MinuteCore tests are only required for business logic changes. UI layout fixes are verified through manual QA.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare development environment and validate prerequisites

- [X] T001 Verify project builds successfully in Xcode 15.x
- [X] T002 Validate current window minimum size is 860x620 in Minute/Sources/Views/ContentView.swift line ~24
- [X] T003 [P] Identify FloatingControlBar fixed width constraint (560px) in Minute/Sources/Views/ContentView.swift line ~1040
- [X] T004 [P] Review MeetingNotesSidebarView List constraints in Minute/Sources/Views/MeetingNotes/MeetingNotesSidebarView.swift

**Checkpoint**: Environment ready, current implementation understood

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T005 Update minimum window size from 860x620 to 600x400 in Minute/Sources/Views/ContentView.swift line ~24
- [ ] T006 Test app launches with new minimum window size without errors
- [ ] T007 Verify window size enforcement - attempt to resize window below 600x400 and confirm system prevents it

**Checkpoint**: Foundation ready - window constraints updated and enforced, user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - View Meeting History List (Priority: P1) 🎯 MVP

**Goal**: Fix meeting list viewport overflow so all meetings are visible and accessible within window bounds on all macOS configurations

**Independent Test**: Open app on MacBook Pro 14-inch (macOS 15.7.3), verify all meeting sections (Today, Yesterday, Last Week, Last Month) are visible within sidebar bounds without content clipping or overflow

### Implementation for User Story 1

- [X] T008 [US1] Add explicit frame constraints to MeetingNotesSidebarView content in Minute/Sources/Views/MeetingNotes/MeetingNotesSidebarView.swift
- [X] T009 [US1] Verify List has proper frame modifiers `.frame(maxWidth: .infinity, maxHeight: .infinity)` in MeetingNotesSidebarView body
- [ ] T010 [US1] Test meeting list with 0 meetings (empty state) - verify layout correct
- [ ] T011 [US1] Test meeting list with 5 meetings - verify all visible without scroll
- [ ] T012 [US1] Test meeting list with 20+ meetings - verify scroll appears and works correctly
- [ ] T013 [US1] Test at window size 600x400 - verify meeting list visible within bounds
- [ ] T014 [US1] Test at window size 1200x800 - verify meeting list scales properly
- [ ] T015 [US1] Test on MacBook Pro 14-inch (macOS 15.7.3) - verify original bug is fixed

**Checkpoint**: Meeting list viewport overflow is resolved. List stays within sidebar bounds at all window sizes and hardware configurations.

---

## Phase 4: User Story 2 - Access Meeting Type Selector (Priority: P1)

**Goal**: Fix meeting type selector positioning so it's fully visible and accessible, not obscured by the record button

**Independent Test**: Open recording interface, click meeting type picker to open dropdown, verify it opens normally without requiring UI repositioning

### Implementation for User Story 2

- [X] T016 [P] [US2] Wrap FloatingControlBar in GeometryReader in Minute/Sources/Views/ContentView.swift around line 86
- [X] T017 [P] [US2] Calculate 70% of geometry width for control bar sizing in Minute/Sources/Views/ContentView.swift (add validation: log/verify calculated width value)
- [X] T018 [US2] Remove fixed maxWidth: 560 constraint from FloatingControlBar styling in Minute/Sources/Views/ContentView.swift line ~1040
- [X] T019 [US2] Increase HStack spacing from 12 to 16 in FloatingControlBar in Minute/Sources/Views/ContentView.swift line ~984
- [X] T020 [US2] Increase Spacer minLength from 16 to 24 in FloatingControlBar in Minute/Sources/Views/ContentView.swift line ~996
- [ ] T021 [US2] Optional: Add minWidth: 180 to MeetingTypePicker frame if still cramped in Minute/Sources/Views/ContentView.swift
- [ ] T022 [US2] Test meeting type picker visibility at 600x400 window - verify fully visible
- [ ] T023 [US2] Test meeting type picker interaction - click and verify dropdown opens normally
- [ ] T024 [US2] Test all meeting types can be selected without control overlap
- [ ] T025 [US2] Test meeting type picker visibility at various window sizes (800x600, 1200x800, fullscreen)

**Checkpoint**: Meeting type selector is fully accessible and not obscured by any controls. All interactions work smoothly at all window sizes.

---

## Phase 5: User Story 3 - Utilize Full Window Width (Priority: P2)

**Goal**: Expand control bar to utilize 70%+ of content area width, providing adequate spacing between all controls

**Independent Test**: View control bar at different window sizes, verify it spans approximately 70% of content width (excluding window chrome) with comfortable control spacing

### Implementation for User Story 3

- [X] T026 [US3] Verify control bar centers properly with `.frame(maxWidth: .infinity)` in Minute/Sources/Views/ContentView.swift
- [ ] T027 [US3] Test control bar width at 600x400 window - verify ~70% of content area
- [ ] T028 [US3] Test control bar width at 800x600 window - measure actual percentage
- [ ] T029 [US3] Test control bar width at 1200x800 window - verify proportional scaling
- [ ] T030 [US3] Test control bar width at fullscreen - verify efficient space utilization
- [ ] T031 [US3] Verify all controls have clear visual separation (no overlap or touching)
- [ ] T032 [US3] Verify control spacing is comfortable and clickable targets are adequate

**Note**: GeometryReader calculation implemented in T017 (US2); this phase verifies the 70% width requirement is met across window sizes.

**Checkpoint**: Control bar efficiently utilizes window width (70%+) with proper spacing. Layout is responsive across all window sizes.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Validation, regression testing, and final verification

- [ ] T033 [P] Execute full QA checklist from specs/007-fix-ui-layout/checklists/qa.md
- [ ] T034 [P] Regression test: Verify recording functionality still works (start/stop)
- [ ] T035 [P] Regression test: Verify processing pipeline unaffected
- [ ] T036 [P] Regression test: Verify meeting notes browser interactions work
- [ ] T037 [P] Regression test: Verify settings view displays correctly
- [ ] T038 Test window resize behavior - rapid resizing multiple times without crashes
- [ ] T039 Test with long meeting titles (100+ chars) - verify graceful wrapping/truncation
- [ ] T040 Test on macOS 14.x for backward compatibility (if available)
- [ ] T041 Validate all success criteria from spec.md are met (SC-001 through SC-006)
- [ ] T042 Run quickstart.md validation steps
- [ ] T043 Document any edge cases or observations in QA checklist

**Checkpoint**: All user stories complete, all success criteria met, zero regressions, ready for PR.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - US1 (meeting list) can proceed independently after Phase 2
  - US2 (control bar layout) can proceed independently after Phase 2
  - US3 (width utilization) depends on US2 (same file, same component)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - Independent implementation
- **User Story 2 (P1)**: Can start after Foundational (Phase 2) - Independent implementation
- **User Story 3 (P2)**: Depends on User Story 2 (same component, builds on US2 changes)

### Within Each User Story

- US1: Implementation → Testing → Validation (linear within story)
- US2: Implementation tasks can be partially parallelized → Testing → Validation
- US3: Verification tasks building on US2 changes → Testing → Validation

### Parallel Opportunities

- **Phase 1 Setup**: T002, T003, T004 can run in parallel (different files/analysis)
- **User Stories**: US1 and US2 can be worked on in parallel by different developers (different files)
- **Phase 2 Implementation**: T015, T016 can be prepared in parallel (same change set)
- **Phase 2 Implementation**: T017, T018, T019 affect same file but can be done in single commit
- **Phase 6 Polish**: T033, T034, T035, T036, T037 are independent test activities (can parallelize)

---

## Parallel Example: User Story 2

```bash
# Prepare layout changes together:
Task T015: "Wrap FloatingControlBar in GeometryReader" (setup)
Task T016: "Calculate 70% width" (logic)

# Apply styling changes together in one commit:
Task T017: "Remove fixed maxWidth"
Task T018: "Increase HStack spacing"
Task T019: "Increase Spacer minLength"

# Run tests in parallel:
Task T021: "Test picker visibility at 600x400"
Task T024: "Test picker at various sizes"
```

---

## Implementation Strategy

### MVP First (User Stories 1 & 2 Only - Both P1)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (update minimum window size)
3. Complete Phase 3: User Story 1 (fix meeting list overflow) → **Test independently**
4. Complete Phase 4: User Story 2 (fix meeting type selector) → **Test independently**
5. **STOP and VALIDATE**: Both critical bugs fixed, ready for deployment
6. Deploy/demo if ready (US3 can be done later as P2 enhancement)

### Full Feature Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Meeting list works ✓
3. Add User Story 2 → Test independently → Control bar fixed ✓
4. Add User Story 3 → Test independently → Width optimization ✓
5. Complete Phase 6: Polish & Cross-Cutting → Full QA, zero regressions ✓
6. Ready for PR and merge

### Parallel Team Strategy (Optional)

With two developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - **Developer A**: User Story 1 (MeetingNotesSidebarView.swift)
   - **Developer B**: User Stories 2 & 3 (ContentView.swift FloatingControlBar)
3. Stories complete and integrate independently (different files)
4. Team executes Phase 6 QA together

---

## Notes

- **No MinuteCore changes**: All tasks are in Minute/Sources/Views/ (UI layer only)
- **No tests required**: Per constitution, UI layout fixes verified through manual QA
- **File isolation**: US1 and US2 touch different files, can proceed in parallel
- **Quick wins**: Both P1 stories can be done in 2-3 hours total
- **QA is critical**: Manual testing on target hardware (MacBook Pro 14-inch, macOS 15.7.3) required
- **Constitution compliance**: Zero impact on output contract, pipeline, or MinuteCore logic

---

## Task Count Summary

- **Total Tasks**: 43
- **Setup (Phase 1)**: 4 tasks
- **Foundational (Phase 2)**: 3 tasks  
- **User Story 1 (P1)**: 8 tasks
- **User Story 2 (P1)**: 10 tasks
- **User Story 3 (P2)**: 7 tasks
- **Polish (Phase 6)**: 11 tasks

**Parallel Opportunities**: 12 tasks marked [P] can run concurrently
**Independent Stories**: US1 and US2 can be developed in parallel (different files)
**MVP Scope**: Phases 1-4 (US1 + US2) = 25 tasks, estimated 2-3 hours
