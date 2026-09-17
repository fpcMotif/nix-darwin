---
name: macos-liquid-glass-appkit
description: "AppKit and SwiftUI Liquid Glass (NSGlassEffectView) styling, transparency, and performance guidelines for macOS 26+. Covers transparent backdrop setup, NSGlassEffectView.Style.clear, specular rim highlights, and legibility contrast."
---

# macOS Liquid Glass AppKit Guidelines

Guidelines and procedures for implementing crystal-clear, high-performance Liquid Glass interface elements on macOS 26+ using AppKit (`NSGlassEffectView`) and SwiftUI.

## 1. Avoid Opaque Visual Effect Backdrops

Never wrap an `NSGlassEffectView` inside an `NSVisualEffectView` with an opaque material like `.hudWindow`. 
- `.hudWindow` is a pitch-dark HUD material that completely blocks window translucency and background wallpaper sampling.
- Allow `NSGlassEffectView` to serve as the root container or background view directly so it can sample and refract the desktop wallpaper and behind-window content.

```swift
// GOOD: NSGlassEffectView as root container
let glassView = NSGlassEffectView()
glassView.style = .clear // Or .regular
glassView.cornerRadius = 30
glassView.contentView = hostingController.view

let glassController = NSViewController()
glassController.view = glassView
```

## 2. Choosing `NSGlassEffectView.Style`

- `glassView.style = .clear`: Delivers crystal-clear, luminous, liquid transparency where background content and wallpaper bleed through sharply with soft optical blur.
- `glassView.style = .regular`: Provides heavier frosted/opaque glass. Use `.clear` when true liquid transparency is desired.

## 3. Specular Rim Light Highlights

Real physical glass catches ambient light along continuous-curve capsule edges. Add a subtle 0.5px specular rim gradient stroke overlay:

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

## 4. Typography & Contrast Accessibility

When text renders over crystal-clear glass (`.clear`), ensure contrast stays WCAG AA compliant (> 4.5:1 ratio):
- Use `.primary` for main titles.
- Elevate metadata subtitles to `font(size: 11.5, weight: .medium)` to maintain readability over complex desktop wallpapers.
- Ensure Increase Contrast mode (`colorSchemeContrast == .increased`) strengthens border strokes and background opacities.

## 5. Performance Optimization

- Disable non-essential layout animations during rapid typing or scrolling (`transaction.disablesAnimations = true`).
- Keep search debounce low (15–20ms) for instant typing feedback.
- Use smooth, fast spring animation curves (e.g. `160ms` duration with `CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)`).
