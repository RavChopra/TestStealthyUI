# MessageKit-Style Bubble Alignment Implementation

## Overview

This document describes the UIKit/AppKit-based message bubble implementation that brings MessageKit-level constraint precision to SwiftUI chat bubbles in the TestStealthyUI project.

## Problem

SwiftUI's layout system was producing inconsistent alignment for chat bubbles:
- **Short user messages** would drift left or center instead of staying flush-right
- **Bubble width** would sometimes expand to fill available space rather than hugging content
- **Text alignment** inside bubbles was difficult to control independently from bubble alignment

## Solution

We implemented a hybrid approach using **AppKit NSView** (for macOS) wrapped in **NSViewRepresentable** to leverage UIKit/AppKit's Auto Layout constraint system, which provides the same level of precision that MessageKit uses.

## Architecture

### Files

1. **MessageBubbleView.swift** (~326 lines)
   - `BubbleContainerView` (NSView subclass) - Core constraint logic
   - `MessageBubbleView` (NSViewRepresentable) - SwiftUI wrapper
   - `AssistantMessageView` (SwiftUI View) - Plain text for assistant messages
   - Platform support: macOS (AppKit) and iOS (UIKit) via conditional compilation

2. **MessageRow.swift** (~32 lines)
   - Simplified to route to appropriate view type
   - User messages → `MessageBubbleView` (AppKit-based)
   - Assistant messages → `AssistantMessageView` (SwiftUI)

## How It Works

### MessageKit-Style Constraint Layout

The implementation mimics MessageKit's constraint approach:

#### For User Messages (Right-Aligned)
```swift
// Pin bubble's trailing edge to container's trailing edge (REQUIRED priority)
bubbleView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
  .priority = .required

// Allow bubble to shrink from left (lower priority)
bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40)
  .priority = 750  // defaultHigh
```

**Result:** Bubble stays pinned to the right edge; shrinks naturally for short text.

#### For Assistant Messages (Left-Aligned)
```swift
// Pin bubble's leading edge to container's leading edge (REQUIRED priority)
bubbleView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16)
  .priority = .required

// Allow bubble to shrink from right (lower priority)
bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40)
  .priority = 750  // defaultHigh
```

**Result:** Bubble stays pinned to the left edge; expands naturally for content.

### Text Alignment Inside Bubble

```swift
// Text is ALWAYS left-aligned inside the bubble
textField.alignment = .left

// Constraints pin text to bubble edges
textField.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12)
textField.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12)
```

### Width Capping

```swift
// Cap maximum bubble width
bubbleView.widthAnchor.constraint(lessThanOrEqualToConstant: maxBubbleWidth)
  .priority = .required
```

## Key Differences from Pure SwiftUI

| Aspect | SwiftUI (Previous) | AppKit/UIKit (Current) |
|--------|-------------------|------------------------|
| **Alignment** | `.frame(maxWidth: .infinity, alignment: .trailing)` | Auto Layout trailing anchor constraint |
| **Width Control** | `.frame(maxWidth: 520)` | `widthAnchor.constraint(lessThanOrEqualTo:)` |
| **Priority** | Implicit | Explicit constraint priorities |
| **Precision** | Layout engine decides | Developer controls via constraint priorities |

## Benefits

✅ **Pixel-perfect alignment** - User bubbles never drift from right edge
✅ **Natural sizing** - Bubbles shrink to content size, never expand unnecessarily
✅ **Text independence** - Text alignment inside bubble is independent of bubble alignment
✅ **MessageKit parity** - Same constraint logic as production-grade chat UIs
✅ **Cross-platform** - Works on both macOS (AppKit) and iOS (UIKit)

## Usage

```swift
// In ChatView.swift or similar
MessageRow(
    text: "Hello!",
    isUser: true,
    maxBubbleWidth: 520
)
```

The `MessageRow` automatically routes to:
- `MessageBubbleView` (AppKit-based) for user messages
- `AssistantMessageView` (SwiftUI) for assistant messages

## Platform Support

### macOS (AppKit)
- Uses `NSView`, `NSTextField`, `NSViewRepresentable`
- Compiled when `#if os(macOS)`

### iOS (UIKit)
- Uses `UIView`, `UILabel`, `UIViewRepresentable`
- Compiled when `#if !os(macOS)`

## Testing

Build status: ✅ **BUILD SUCCEEDED**

### Visual Tests
1. **Short message** (e.g., "Hi") → Small bubble, flush-right
2. **Long message** → Wraps at maxWidth, stays right-aligned
3. **Multi-line** → Text wraps, bubble grows vertically
4. **Assistant** → No bubble, left-aligned, full readable width

## References

- MessageKit GitHub: https://github.com/MessageKit/MessageKit
- Specifically studied:
  - `MessageContainerView.swift` - Container layout logic
  - `MessageCollectionViewCell.swift` - Cell constraint setup
  - `MessagesCollectionViewFlowLayout.swift` - Flow layout calculations

## Future Improvements

- [ ] Add tap gesture support
- [ ] Implement copy/select text functionality
- [ ] Add avatar support (reserved 40pt gutter)
- [ ] Implement bubble animations (slide in from right/left)
- [ ] Add accessibility labels

---

**Implementation Date:** October 20, 2025
**Author:** Claude (AI Assistant)
**Approach:** MessageKit-inspired constraint-based layout in AppKit/UIKit
