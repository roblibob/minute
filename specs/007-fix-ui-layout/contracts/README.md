# Contracts: UI Layout Fixes

**Branch**: `007-fix-ui-layout`  
**Created**: 2026-02-09

## Overview

This feature has **no API contracts or data contracts** because it consists entirely of UI layout fixes.

## Layout Contracts

While there are no code contracts, the following layout expectations serve as acceptance criteria:

### 1. Minimum Window Size Contract
```text
Window minimum dimensions: 600x400 pixels
- All controls must remain visible and accessible at this size
- No content should be clipped or overflow
- Scroll functionality must work if content exceeds available space
```

### 2. Meeting List Visibility Contract
```text
Meeting list sidebar:
- Must display within NavigationSplitView sidebar bounds
- Width: 320px (min: 320, ideal: 320, max: 320)
- Height: Must not exceed parent container bounds
- Scroll: Standard vertical scroll with always-visible scrollbar when content overflows
- All sections (Today, Yesterday, Last Week, etc.) must be accessible
```

### 3. Floating Control Bar Layout Contract
```text
FloatingControlBar dimensions:
- Width: Minimum 70% of content area width (excluding window chrome)
- Horizontal spacing between control groups: 16-20px
- Controls must not overlap or be obscured
- Meeting type picker must be fully visible and clickable
- Layout must adapt responsively to window resize

Control groups (left to right):
1. Audio mode control
2. Meeting type picker (with label)
3. Screen share + upload buttons
4. Record button (rightmost)
```

### 4. Responsive Behavior Contract
```text
Window resize behavior:
- Control bar width adjusts proportionally (maintains 70%+ of content width)
- Meeting list maintains proper bounds at all sizes
- Compact layout threshold: height < 620px
- All controls remain accessible from 600x400 to full screen
```

## Notes

These layout contracts are enforced through SwiftUI view modifiers and will be verified through manual QA testing on the target hardware configuration (MacBook Pro 14-inch, macOS 15.7.3).
