# Research: UI Layout Fixes

**Branch**: `007-fix-ui-layout`  
**Created**: 2026-02-09  
**Purpose**: Resolve technical unknowns and establish best practices for SwiftUI layout fixes

## 1. SwiftUI List Constraint Management

### Decision
Use `.frame(maxWidth: .infinity, maxHeight: .infinity)` on the List container with explicit `.listStyle(.sidebar)` and proper parent container constraints.

### Rationale
- SwiftUI `List` can exceed parent bounds if not properly constrained
- The `NavigationSplitView` sidebar column needs explicit `navigationSplitViewColumnWidth` modifiers (already present: `min: 320, ideal: 320, max: 320`)
- Adding `.frame(maxWidth: .infinity, maxHeight: .infinity)` ensures the List respects its parent's bounds
- The `.scrollContentBackground(.hidden)` modifier (already in use) is correct for custom backgrounds

### Implementation Strategy
Check if `MeetingNotesSidebarView` has proper frame modifiers. The List itself should be wrapped in a container with explicit frame constraints to prevent overflow.

### Alternatives Considered
1. **ScrollView wrapper**: Not needed - List already has scrolling built-in
2. **GeometryReader approach**: Overly complex for this use case
3. **Custom layout container**: Unnecessary - SwiftUI frame modifiers sufficient

## 2. FloatingControlBar Width Management

### Decision
Replace fixed `maxWidth: 560` constraint with a percentage-based width calculation using `GeometryReader` at the parent level to achieve 70%+ of content area width.

### Rationale
- Current implementation in `ContentView.swift` line 241 uses `.frame(maxWidth: 560)` on the `FloatingControlBar`
- This hardcoded width doesn't adapt to window size and causes control crowding
- Using `GeometryReader` in the parent ZStack allows calculating 70% of available content width
- Maintains responsive layout across different window sizes

### Implementation Strategy
```swift
// In ContentView.swift, modify floatingControlBar:
GeometryReader { geometry in
    floatingControlBar
        .frame(maxWidth: geometry.size.width * 0.7)
        .frame(maxWidth: .infinity) // Center the bar
        .padding(.bottom, isCompactLayout ? 12 : 22)
}
```

### Alternatives Considered
1. **Fixed wider width (e.g., 800px)**: Doesn't adapt to small windows
2. **100% width**: Too wide, loses visual hierarchy
3. **Custom layout protocol**: Overly complex for this requirement

## 3. Control Spacing and Z-Index Management

### Decision
Increase horizontal spacing in `FloatingControlBar` `HStack` from `spacing: 12` to `spacing: 16-20` and ensure proper `Spacer(minLength: )` usage to prevent overlap.

### Rationale
- Current layout has multiple `HStack(spacing: 12)` sections that create crowding
- The MeetingTypePicker is in a VStack with the "Meeting type" label, competing for space
- Increasing spacing and using explicit `Spacer(minLength: 24)` prevents controls from overlapping
- Z-index issues are unlikely in HStack layouts (unlike ZStack) but can verify with `.zIndex()` if needed

### Implementation Strategy
1. Increase outer HStack spacing to 16
2. Ensure `Spacer(minLength: 24)` between control groups
3. Review `MeetingTypePicker` VStack alignment and spacing
4. Consider making the picker wider with `.frame(minWidth: 180)`

### Alternatives Considered
1. **Rearranging control order**: Would break existing UX patterns
2. **Multi-row layout**: Increases vertical space usage unnecessarily
3. **Hiding controls conditionally**: Reduces functionality

## 4. Minimum Window Size Enforcement

### Decision
Set minimum window size to 600x400 in SwiftUI using `.frame(minWidth: 600, minHeight: 400)` on the root ContentView.

### Rationale
- Current `ContentView.swift` line 24 has `.frame(minWidth: 860, minHeight: 620)` which is too large
- Spec requires 600x400 minimum for broader hardware compatibility
- macOS respects `.frame(min/maxWidth/Height)` modifiers on the root view
- This ensures all controls remain accessible at the minimum size

### Implementation Strategy
Update line 24 in `ContentView.swift`:
```swift
.frame(minWidth: 600, minHeight: 400)
```

Also verify that `SettingsView` has appropriate sizing (currently 680x480).

### Alternatives Considered
1. **NSWindow.minSize in AppDelegate**: Requires app delegate pattern (not using in SwiftUI App lifecycle)
2. **Custom window controller**: Overly complex for simple size constraint
3. **WindowGroup modifier**: `.defaultSize()` doesn't enforce minimums

## 5. Testing Strategy

### Decision
Manual QA on target hardware (MacBook Pro 14-inch, macOS 15.7.3) with systematic window resize testing.

### Rationale
- UI layout bugs are visual issues best caught through manual testing
- No unit tests needed for pure layout changes (per constitution - tests required for MinuteCore logic only)
- QA checklist should cover:
  1. Meeting list visibility at min/max window sizes
  2. Control bar width and spacing at various sizes
  3. Meeting type picker accessibility
  4. Scroll behavior in meeting list
  5. Regression check: recording and processing still work

### Test Plan
1. Open app on MacBook Pro 14-inch (Nov 2023) running macOS 15.7.3
2. Resize window to minimum (600x400) - verify all controls visible
3. Resize to maximum - verify layout utilizes space efficiently
4. Verify meeting list scrolls properly with 20+ meetings
5. Interact with meeting type picker - verify no overlap with record button
6. Verify control bar spans 70%+ of content width
7. Test on macOS 14.x for backward compatibility

### Alternatives Considered
1. **Snapshot tests**: Could be added but overkill for simple layout fix
2. **Automated UI tests**: Too brittle for this level of layout testing
3. **Unit tests for layout logic**: No logic to test - pure declarative SwiftUI

## 6. SwiftUI Layout Best Practices

### Research Findings
- Use `.frame()` modifiers explicitly rather than relying on implicit sizing
- `NavigationSplitView` requires explicit column width modifiers
- `List` should be constrained with `.frame(maxWidth: .infinity, maxHeight: .infinity)` to prevent overflow
- `GeometryReader` is appropriate for percentage-based layouts
- Prefer `Spacer(minLength:)` over fixed padding for flexible layouts
- HStack spacing should be 16-20 for comfortable touch targets and visual separation

### References
- Apple Human Interface Guidelines: Spacing and layout grids
- SwiftUI documentation: NavigationSplitView, List, GeometryReader
- Existing codebase patterns: `MainSettingsView` sizing, `FloatingControlBar` structure

## Summary

All technical unknowns have been resolved:
1. **Meeting list overflow**: Fix with proper frame constraints on List container
2. **Control bar width**: Use GeometryReader for 70% content width calculation  
3. **Control spacing**: Increase HStack spacing to 16-20 and use explicit Spacers
4. **Minimum window size**: Reduce from 860x620 to 600x400 in root ContentView
5. **Testing**: Manual QA on target hardware with resize testing

No NEEDS CLARIFICATION items remain. Ready for Phase 1 (design artifacts).
