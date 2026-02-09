# Feature Specification: UI Layout Fixes

**Feature Branch**: `007-fix-ui-layout`  
**Created**: 2026-02-09  
**Status**: Draft  
**Input**: User description: "Fix UI layout bugs: meeting list viewport overflow and meeting type selector positioning"

## Clarifications

### Session 2026-02-09

- Q: What is the primary cause of the viewport overflow issue? → A: The meeting list container has incorrect SwiftUI layout constraints causing it to extend beyond its parent view bounds - fix by adjusting constraint priorities and ensuring proper clipping.
- Q: Which UI component is the "floating control bar"? → A: Main recording control bar (the bar with microphone/speaker/broadcast buttons and meeting type selector)
- Q: What does "70% of the available window width" measure from? → A: Content area width (excluding window chrome and margins)
- Q: What is the minimum supported window size for the application? → A: 600x400 minimum (standard compact desktop size)
- Q: How should the meeting list handle overflow when content exceeds available space? → A: Standard vertical scroll with always-visible scrollbar indicator (already implemented, needs constraint fixes to work properly)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Meeting History List (Priority: P1)

Users need to access their complete meeting history without content being cut off or positioned outside the viewable area. On some configurations (specifically macOS 15.7.3 on MacBook Pro 14-inch Nov 2023), the meeting list content extends beyond the visible viewport, preventing users from seeing or interacting with all their meetings.

**Why this priority**: This is a critical usability bug that blocks primary functionality - users cannot access their meeting history if it's not visible. Without this fix, the application is unusable for affected users.

**Independent Test**: Open the application on the affected hardware/OS configuration, navigate to the meeting history view, and verify that all meetings (including those from "YESTERDAY", "LAST WEEK", "LAST MONTH" categories) are visible and accessible within the window bounds. Verify that scrolling (if needed) works correctly and no content is clipped.

**Acceptance Scenarios**:

1. **Given** a user opens the Minute application on macOS 15.7.3 (MacBook Pro 14-inch), **When** they view the meeting history sidebar, **Then** all meeting list items are visible within the window viewport and accessible
2. **Given** a user has meetings from different time periods (yesterday, last week, last month), **When** they browse the list, **Then** all category headers and meeting items are visible without requiring window resizing
3. **Given** a user with more meetings than fit in one screen, **When** they scroll the meeting list, **Then** the scrolling works smoothly and all content remains within proper boundaries

---

### User Story 2 - Access Meeting Type Selector (Priority: P1)

Users need to select the meeting type before starting a recording. Currently, the meeting type dropdown is positioned behind the record/start button in the main recording control bar (the bar with microphone/speaker/broadcast buttons), making it difficult or impossible to access the selector when needed.

**Why this priority**: This is a critical usability bug that blocks a primary workflow - users must be able to select meeting type before recording. If the control is hidden or obscured, users cannot properly configure their recording.

**Independent Test**: Open the recording interface, observe the main recording control bar, and verify that the meeting type selector is fully accessible and not obscured by any other controls. Click the selector to verify it can be interacted with normally.

**Acceptance Scenarios**:

1. **Given** a user is on the recording screen, **When** they look at the main recording control bar, **Then** the meeting type selector is fully visible and not obscured by the record button or any other UI elements
2. **Given** a user wants to change the meeting type, **When** they click the meeting type dropdown, **Then** it opens normally without requiring them to move other UI elements out of the way
3. **Given** a user on various window sizes, **When** they view the main recording control bar, **Then** all controls (meeting type selector, record button, other buttons) remain visible and accessible

---

### User Story 3 - Utilize Full Window Width (Priority: P2)

The main recording control bar should make efficient use of available screen space. Currently it appears narrower than necessary, which contributes to the crowding that causes the meeting type selector to be hidden behind other controls.

**Why this priority**: This improves the overall user experience and helps prevent future layout issues by giving controls more breathing room. It's lower priority than fixing the immediate accessibility bugs but should be addressed as part of the same layout fix.

**Independent Test**: View the main recording control bar on different window sizes and verify that it spans an appropriate width of the window (e.g., 80-90% of window width or within sensible margins), providing adequate space for all controls without overcrowding.

**Acceptance Scenarios**:

1. **Given** a user views the recording interface, **When** they observe the main recording control bar, **Then** it spans at least 70% of the content area width while maintaining appropriate margins
2. **Given** a user resizes the application window, **When** the window width changes, **Then** the main recording control bar adjusts proportionally to maintain efficient use of space
3. **Given** a user with controls in the control bar, **When** viewing them at the expanded width, **Then** all controls have adequate spacing and remain easily clickable

---

### Edge Cases

- What happens when the window is resized to the minimum supported dimensions (600x400)? All critical controls must remain accessible.
- How does the layout behave on different screen resolutions and display scaling settings?
- What happens when users have very long meeting titles in the history list? Text should wrap or truncate gracefully without breaking the layout.
- How does the main recording control bar handle varying content (different meeting type names, additional controls added in future)?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Meeting history list MUST be fully visible within the application window viewport on all supported macOS versions and hardware configurations (root cause: incorrect SwiftUI layout constraints causing container to extend beyond parent view bounds)
- **FR-002**: Meeting history list container MUST have proper constraint priorities and clipping enabled to prevent content overflow
- **FR-003**: Meeting history list MUST support scrolling when content exceeds available vertical space (preserve existing scroll behavior with standard vertical scroll and always-visible scrollbar indicator)
- **FR-004**: All meeting list items (including those in "YESTERDAY", "LAST WEEK", "LAST MONTH" categories) MUST be accessible and clickable
- **FR-005**: Meeting type selector control MUST be fully visible and not obscured by other UI elements in the main recording control bar
- **FR-006**: Meeting type selector MUST remain accessible and clickable at all times when the recording interface is visible
- **FR-007**: Main recording control bar MUST utilize window width efficiently to provide adequate space for all controls
- **FR-008**: All controls in the main recording control bar (meeting type selector, record button, other buttons) MUST have clear visual separation and not overlap
- **FR-009**: Layout MUST adapt gracefully to different window sizes while maintaining control accessibility
- **FR-010**: UI MUST maintain proper layout bounds on MacBook Pro 14-inch (Nov 2023) running macOS 15.7.3 (24G419)
- **FR-011**: Application MUST enforce a minimum window size of 600x400 pixels, below which all critical controls remain accessible and properly laid out

### Non-Functional Requirements *(mandatory)*

- **NFR-001**: Layout fixes MUST not impact application performance or responsiveness
- **NFR-002**: Changes MUST work across all supported macOS versions (macOS 14+)
- **NFR-003**: UI adjustments MUST follow existing design patterns and visual style
- **NFR-004**: Layout changes MUST not break existing functionality (meeting selection, recording controls, etc.)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users on MacBook Pro 14-inch (Nov 2023) with macOS 15.7.3 can view and access all meetings in the history list without any content being cut off or positioned outside the viewport
- **SC-002**: 100% of meeting type selector interactions complete successfully without requiring users to reposition UI elements or resize windows
- **SC-003**: Main recording control bar spans at least 70% of the content area width (excluding window chrome and margins), providing adequate spacing between all controls
- **SC-004**: Users can successfully access and interact with all recording controls (meeting type selector, record button, etc.) on first attempt without confusion or obstruction
- **SC-005**: Zero regression bugs reported in existing meeting list or recording control functionality after layout changes are applied
- **SC-006**: Layout remains functional across window resize operations from minimum supported size to full screen
