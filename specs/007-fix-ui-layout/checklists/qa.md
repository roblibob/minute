# QA Checklist: UI Layout Fixes

**Feature**: 007-fix-ui-layout  
**Created**: 2026-02-09  
**Purpose**: Manual QA verification for UI layout bug fixes

## Pre-Testing Setup

- [ ] Build succeeds without errors
- [ ] App launches successfully
- [ ] Test on MacBook Pro 14-inch (Nov 2023) with macOS 15.7.3 (primary target)
- [ ] Test on macOS 14.x for backward compatibility (if available)

---

## Test Suite 1: Meeting List Viewport (P1 - Critical)

### Test 1.1: Meeting List Visibility at Various Window Sizes
- [ ] **600x400 (minimum)**: All meeting sections visible, no content clipped
- [ ] **800x600 (medium)**: Meeting list displays properly
- [ ] **1200x800 (large)**: Meeting list utilizes space efficiently
- [ ] **Full screen**: Meeting list scales appropriately

### Test 1.2: Meeting List Scrolling
- [ ] With 0-5 meetings: No scroll needed, list displays normally
- [ ] With 10-20 meetings: Scroll appears, works smoothly
- [ ] With 50+ meetings: Scroll handles large dataset without lag
- [ ] Scrollbar is visible when content exceeds viewport (per spec)

### Test 1.3: Meeting List Content Integrity
- [ ] All sections visible: Today, Yesterday, Last Week, Last Month, etc.
- [ ] All meeting items clickable and interactive
- [ ] Meeting titles display correctly (no truncation issues)
- [ ] Time labels and metadata visible
- [ ] Context menus work on all meeting items

### Test 1.4: Meeting List Bounds Verification
- [ ] List content stays within sidebar bounds (320px width)
- [ ] No content extends beyond bottom of window
- [ ] No horizontal scrolling appears (width constrained properly)
- [ ] Disclosure group expand/collapse works correctly

**Success Criteria**: SC-001 from spec - all meetings accessible without clipping ✓

---

## Test Suite 2: Meeting Type Selector Accessibility (P1 - Critical)

### Test 2.1: Meeting Type Picker Visibility
- [ ] Meeting type picker fully visible in control bar
- [ ] Picker not obscured by record button
- [ ] Picker not obscured by other controls
- [ ] "Meeting type" label visible above picker

### Test 2.2: Meeting Type Picker Interaction
- [ ] Click picker opens dropdown menu
- [ ] All meeting types listed (Autodetect, General, Standup, etc.)
- [ ] Select different type - selection updates
- [ ] Picker remains accessible after selection
- [ ] Picker works while recording (per code comment)

### Test 2.3: Meeting Type Picker at Various Window Sizes
- [ ] **600x400 (minimum)**: Picker fully visible and clickable
- [ ] **800x600 (medium)**: Picker displays with adequate spacing
- [ ] **1200x800 (large)**: Picker not cramped or excessive
- [ ] **Window resize**: Picker remains accessible throughout resize

**Success Criteria**: SC-002 from spec - 100% of selector interactions successful ✓

---

## Test Suite 3: Control Bar Layout (P1 - Critical)

### Test 3.1: Control Bar Width
- [ ] Control bar spans approximately 70% of content area width
- [ ] Width measured excluding window chrome (title bar, borders)
- [ ] Control bar width adjusts proportionally when window resizes
- [ ] Control bar remains centered in window

### Test 3.2: Control Spacing and Separation
- [ ] Audio mode control (left) has clear separation
- [ ] Meeting type picker has adequate space (not cramped)
- [ ] Screen share + upload buttons separated clearly
- [ ] Record button (right) has adequate spacing from other controls
- [ ] No controls overlap or touch

### Test 3.3: Control Bar at Various Window Sizes
- [ ] **600x400 (minimum)**: All controls visible, properly spaced
- [ ] **800x600 (medium)**: Controls have comfortable spacing
- [ ] **1200x800 (large)**: Control bar utilizes width efficiently
- [ ] **Window resize**: Controls adapt smoothly, no layout jumps

### Test 3.4: All Control Bar Buttons Functional
- [ ] Audio mode selector (Room/Online/Both) works
- [ ] Meeting type picker works (covered in Suite 2)
- [ ] Screen share toggle works (if enabled)
- [ ] Upload button works
- [ ] Record button works (start/stop)

**Success Criteria**: SC-003, SC-004 from spec - control bar 70%+ width, all controls accessible ✓

---

## Test Suite 4: Window Size Constraints (P2)

### Test 4.1: Minimum Window Size Enforcement
- [ ] Window cannot be resized below 600x400
- [ ] macOS enforces minimum size (try to resize smaller)
- [ ] At minimum size, all critical controls visible and functional

### Test 4.2: Responsive Layout Behavior
- [ ] Resize from minimum to maximum - layout adapts smoothly
- [ ] No layout "jumps" or sudden repositioning
- [ ] Compact layout triggers at height < 620px (per existing code)
- [ ] Status drawer positioning adjusts correctly in compact mode

**Success Criteria**: SC-006 from spec - layout functional from min to max size ✓

---

## Test Suite 5: Regression Testing (P1 - Critical)

### Test 5.1: Recording Functionality
- [ ] Start recording - audio capture begins
- [ ] Stop recording - audio capture stops
- [ ] Recording UI updates correctly (levels, timer)
- [ ] Record button state changes appropriately

### Test 5.2: Processing Pipeline
- [ ] Process recorded audio - transcription runs
- [ ] Summarization completes successfully
- [ ] Files written to vault correctly
- [ ] Meeting appears in sidebar after processing

### Test 5.3: Meeting Notes Browser
- [ ] Select meeting from sidebar - details display
- [ ] Open summary in app - content loads
- [ ] Open transcript in app - content loads
- [ ] Meeting list interactions unchanged

### Test 5.4: Settings and Other Views
- [ ] Open settings - layout correct
- [ ] Permissions section accessible
- [ ] Other settings panels work normally
- [ ] Close settings - return to main view

### Test 5.5: General App Functionality
- [ ] App menu items work
- [ ] Keyboard shortcuts functional
- [ ] Notifications work (if enabled)
- [ ] App quit and relaunch works

**Success Criteria**: SC-005 from spec - zero regression bugs ✓

---

## Test Suite 6: Edge Cases

### Test 6.1: Long Meeting Titles
- [ ] Very long meeting title (100+ chars) - wraps or truncates gracefully
- [ ] Multiple meetings with long titles - sidebar handles correctly
- [ ] Long titles don't break meeting list layout

### Test 6.2: Empty States
- [ ] No meetings yet - empty state displays correctly
- [ ] First meeting recorded - appears in list properly

### Test 6.3: Display Scaling
- [ ] Test with different display scaling settings (if possible)
- [ ] Retina vs non-Retina display (if available)
- [ ] External monitor with different resolution

### Test 6.4: Rapid Window Resize
- [ ] Quickly resize window multiple times - no crashes
- [ ] Layout updates smoothly throughout
- [ ] No memory leaks or performance degradation

---

## Hardware-Specific Testing

### MacBook Pro 14-inch (Nov 2023), macOS 15.7.3
- [ ] Meeting list viewport issue resolved (primary bug)
- [ ] Control bar layout correct
- [ ] All test suites pass on target hardware

### macOS 14.x Compatibility (if available)
- [ ] App launches and runs on macOS 14
- [ ] Layout changes work correctly
- [ ] No macOS 15-specific SwiftUI features break compatibility

---

## Sign-Off

**Tester**: ________________________  
**Date**: ________________________  
**Result**: ☐ Pass ☐ Fail ☐ Pass with Notes  

**Notes**:
```
[Record any issues, unexpected behavior, or observations here]
```

**Blockers** (if any):
```
[List any issues that must be resolved before merge]
```

**Recommendations** (optional):
```
[Suggest any improvements or follow-up work]
```
