---
name: macos-appkit-liquid-glass-qa
description: "Building, styling, and E2E visual QA for macOS AppKit + SwiftUI Liquid Glass applications"
---

# macOS AppKit Liquid Glass & E2E Visual QA

Guidelines and procedures for building, styling, and visually auditing AppKit + SwiftUI macOS apps featuring Liquid Glass (`NSGlassEffectView`) on macOS 26+.

## 1. Toolchain & Build Setup

When CommandLineTools SDK version differs from Xcode toolchain, explicitly pass `DEVELOPER_DIR` and `SDKROOT` to `swift build` / `swift test` / `make`:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk \
swift build -c release
```

## 2. Liquid Glass (`NSGlassEffectView`) Styling

- **Pure Transparency**: Use `NSGlassEffectView` directly as the container view (`glassView.style = .clear` on macOS 26+). NEVER wrap `NSGlassEffectView` inside an `NSVisualEffectView` with `.hudWindow` material — `.hudWindow` is an opaque dark HUD material that blocks window transparency and destroys desktop background sampling.
- **Specular Rim Light Highlight**: Add a 0.5px outer specular border stroke with a subtle top-leading to bottom-trailing opacity gradient to catch light along continuous-curve capsule edges:

```swift
.overlay {
    RoundedRectangle(cornerRadius: FloodlightMetrics.cornerRadius, style: .continuous)
        .strokeBorder(
            LinearGradient(
                colors: [.white.opacity(0.35), .white.opacity(0.12), .white.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: 0.5
        )
}
```

## 3. E2E Visual & Stress QA via AppleScript

1. **Trigger & Keystroke Injection**:
```bash
osascript -e '
tell application "System Events"
    tell process "Floodlight"
        click menu bar item 1 of menu bar 2
        delay 0.3
        click menu item "Show Floodlight" of menu 1 of menu bar item 1 of menu bar 2
    end tell
end tell
delay 0.3
tell application "System Events"
    keystroke "safari"
    delay 0.8
end tell
'
```

2. **Screen Capture & Inspection**:
```bash
screencapture -x /tmp/qa-shot.png
```

3. **High-Frequency Keystroke Stress Test**:
Simulate 1,000 rapid keystroke inputs, filter switches (`Cmd+1`–`Cmd+5`), arrow navigation (`key code 125`/`126`), and query clearing (`Cmd+A` + backspace) to verify zero frame dropping, generation cancellation stability, and sub-millisecond search execution.
