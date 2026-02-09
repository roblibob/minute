# Quickstart Guide: UI Layout Fixes

**Branch**: `007-fix-ui-layout`  
**Created**: 2026-02-09  
**Estimated Duration**: 2-3 hours

## Prerequisites

- Xcode 15.x with Swift 5.9+
- macOS 14+ development machine
- Access to MacBook Pro 14-inch (Nov 2023) with macOS 15.7.3 for testing (or similar)
- Existing Minute project cloned and building

## Implementation Steps

### 1. Fix Meeting List Viewport Overflow (30 minutes)

**File**: `Minute/Sources/Views/MeetingNotes/MeetingNotesSidebarView.swift`

**Current Issue**: List content extends beyond parent view bounds on certain hardware configurations.

**Changes**:
```swift
// In MeetingNotesSidebarView, ensure the content view has explicit frame constraints:

var body: some View {
    content
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // ADD THIS if missing
        .background(MinuteTheme.sidebarBackground)
}

// The List itself should already have .listStyle(.sidebar) and proper modifiers
// Verify that the sidebar column width is properly set in ContentView:
.navigationSplitViewColumnWidth(min: 320, ideal: 320, max: 320)  // Should already exist
```

**Rationale**: The `.frame(maxWidth: .infinity, maxHeight: .infinity)` constrains the sidebar content to respect its parent container bounds, preventing overflow.

**Test**: Open app, verify all meeting list sections are visible and scrollable without content extending beyond sidebar bounds.

---

### 2. Update Minimum Window Size (10 minutes)

**File**: `Minute/Sources/Views/ContentView.swift`

**Current**: Line ~24 has `.frame(minWidth: 860, minHeight: 620)`

**Change**:
```swift
// Replace existing frame modifier:
.frame(minWidth: 600, minHeight: 400)
```

**Rationale**: Reduces minimum window size to 600x400 per spec requirements, improving compatibility with smaller displays while maintaining usability.

**Test**: Resize window to 600x400 and verify all controls remain visible and accessible.

---

### 3. Fix Floating Control Bar Width (45 minutes)

**File**: `Minute/Sources/Views/ContentView.swift`

**Current Issue**: Control bar has fixed `maxWidth: 560` causing crowding and control overlap.

**Location**: Around line 241 in the `floatingControlBar` computed property and line 1040 in `FloatingControlBar` view.

**Changes**:

A. Modify the `floatingControlBar` positioning in `PipelineContentView` body (around line 86):
```swift
// Replace:
floatingControlBar
    .padding(.bottom, isCompactLayout ? 12 : 22)

// With GeometryReader wrapper:
GeometryReader { geometry in
    floatingControlBar
        .frame(width: geometry.size.width * 0.7, alignment: .center)
        .frame(maxWidth: .infinity)  // Centers the bar
        .padding(.bottom, isCompactLayout ? 12 : 22)
}
.frame(height: floatingBarHeight, alignment: .bottom)
```

B. Remove the fixed width constraint from FloatingControlBar styling (around line 1040):
```swift
// In FloatingControlBar body, remove:
.frame(maxWidth: 560)  // DELETE THIS LINE

// Keep the rest of the styling
```

C. Increase spacing in FloatingControlBar HStack (around line 984):
```swift
// Change:
HStack(spacing: 12) {  // Line ~984

// To:
HStack(spacing: 16) {  // Increase spacing for better separation
```

D. Ensure adequate spacer between control groups (around line 996):
```swift
// Change:
Spacer(minLength: 16)  // Line ~996

// To:
Spacer(minLength: 24)  // More breathing room
```

**Rationale**: Using GeometryReader calculates 70% of available content width dynamically. Increased spacing prevents control overlap. Removing fixed width allows responsive adaptation.

**Test**: 
1. Verify control bar spans ~70% of window width
2. Resize window and confirm proportional adjustment
3. Verify meeting type picker is fully visible and not obscured by record button
4. Click meeting type picker to verify it's fully interactive

---

### 4. Adjust Control Spacing (15 minutes)

**File**: `Minute/Sources/Views/ContentView.swift`

**Already addressed in step 3**, but verify:
- HStack spacing is 16 (was 12)
- Spacer minLength is 24 (was 16)
- All control groups have clear visual separation

**Optional Enhancement**: If meeting type picker still feels cramped, add minimum width:
```swift
MeetingTypePicker(selection: $meetingType)
    .frame(minWidth: 180)  // ADD THIS
    .disabled(!controlsEnabled && recordState != .recording)
```

---

### 5. Manual QA Testing (30 minutes)

**Test Checklist** (see `checklists/qa.md` for full checklist):

1. **Window Sizing**:
   - [ ] Resize to 600x400 minimum - all controls visible
   - [ ] Resize to full screen - layout utilizes space well
   - [ ] Test various intermediate sizes - responsive behavior

2. **Meeting List**:
   - [ ] All sections visible (Today, Yesterday, Last Week, etc.)
   - [ ] Scroll works smoothly with 20+ meetings
   - [ ] No content clipping or overflow
   - [ ] List remains within sidebar bounds

3. **Control Bar**:
   - [ ] Spans approximately 70% of content width
   - [ ] Meeting type picker fully visible
   - [ ] No overlap between controls
   - [ ] All buttons clickable and responsive

4. **Regressions**:
   - [ ] Recording still works (start/stop)
   - [ ] Processing pipeline unaffected
   - [ ] Meeting notes display correctly
   - [ ] Settings and other views work normally

5. **Target Hardware**:
   - [ ] Test on MacBook Pro 14-inch (Nov 2023) with macOS 15.7.3
   - [ ] Test on macOS 14.x for backward compatibility

---

## Verification

After completing all steps:

1. Build and run: `⌘R` in Xcode
2. Open app on target hardware
3. Execute QA checklist above
4. Verify success criteria from [spec.md](spec.md):
   - SC-001: Meeting list fully visible without clipping ✓
   - SC-002: Meeting type selector 100% accessible ✓  
   - SC-003: Control bar spans 70%+ of content width ✓
   - SC-004: All controls accessible on first attempt ✓
   - SC-005: Zero regressions ✓
   - SC-006: Layout functional from min to max size ✓

## Troubleshooting

**Issue**: Control bar still feels cramped
- **Solution**: Increase spacing further or consider rearranging controls

**Issue**: Meeting list still overflows
- **Solution**: Verify parent NavigationSplitView has explicit column width

**Issue**: Layout breaks at small sizes
- **Solution**: Check that compact layout logic (height < 620) still works correctly

**Issue**: Meeting type picker obscured
- **Solution**: Verify z-index is correct and spacing is adequate

## Next Steps

After verification:
1. Commit changes with message: `fix: resolve meeting list viewport overflow and control bar layout`
2. Create PR for review
3. Deploy and monitor for issues on other hardware configurations

## Resources

- [spec.md](spec.md) - Feature specification
- [research.md](research.md) - Technical research and decisions
- Apple SwiftUI Layout Documentation
- Minute Constitution (for reference)
