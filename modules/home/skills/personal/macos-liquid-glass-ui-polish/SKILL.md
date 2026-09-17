---
name: macos-liquid-glass-ui-polish
description: "Guidelines for styling, debugging translucency, adding specular rim highlights, and visually verifying macOS AppKit/SwiftUI Liquid Glass interfaces."
---

# macOS Liquid Glass UI Polish & Verification

Guidelines and procedures for building, styling, and visually verifying macOS AppKit and SwiftUI Liquid Glass (`NSGlassEffectView`) applications on macOS 26+.

## 1. Transparency & Material Setup

- **Avoid Opaque Backdrops**: Never wrap `NSGlassEffectView` inside an `NSVisualEffectView` configured with dark or opaque materials (such as `.hudWindow`). `.hudWindow` blocks window translucency and destroys wallpaper sampling.
- **Glass Styles**: Use `NSGlassEffectView.Style.clear` on `NSGlassEffectView` for crystal-clear, luminous, liquid transparency over desktop wallpapers. Use `.regular` for heavier frosted surfaces.
- **Window Transparency**:
  - `window.isOpaque = false`
  - `window.backgroundColor = .clear`
  - `window.hasShadow = true`

## 2. Specular Rim Light Highlights

Add a 0.5px specular gradient stroke overlay along `.topLeading` to `.bottomTrailing` to simulate light reflections along continuous-curve glass edges:

```swift
.overlay {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .strokeBorder(
            LinearGradient(
                colors: [
                    .white.opacity(0.35),
                    .white.opacity(0.12),
                    .white.opacity(0.06),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: 0.5
        )
}
```

## 3. Preventing Search Icon & Text Layout Shift

- **Disable Implicit Parent Animations**: Do not apply `.animation(.easeOut, value: query.isEmpty)` to the outer `VStack` containing the search bar. Parent layout interpolation causes search icons and placeholder text to slide or jump during panel expansion.
- **Anchor Search Bars**: Apply `.transaction { $0.animation = nil; $0.disablesAnimations = true }` to the search bar `HStack` and fixed-size icon containers so X, Y coordinates remain 100% fixed during typing and window resizing.
- **Pin Content to Top**: Use `.frame(width: width, alignment: .top)` on the root `VStack` to ensure top-aligned views do not shift vertically when window frame height changes.

## 4. Latency & Spring Motion Optimization

- **Keystroke Debounce**: Keep search keystroke debouncing under 20ms for instant search feedback.
- **Window Resize Animation**: Use short spring timing functions for height expansion: `CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)` with duration `0.16s`.

## 5. Visual QA & Verification Procedure

1. **Build with Xcode Toolchain**: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk make bundle`
2. **Run Test Harness**: Ensure 100% test pass rate on unit, integration, and stress tests.
3. **Capture & Inspect**: Trigger panel via AppleScript and take full-resolution screenshots with `screencapture -x /tmp/screenshot.png`. Check translucency, specular rims, contrast, and layout stability.
