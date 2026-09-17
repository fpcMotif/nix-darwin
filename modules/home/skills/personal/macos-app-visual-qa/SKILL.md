---
name: macos-app-visual-qa
description: "E2E visual QA for macOS apps: launch, trigger via AppleScript, screenshot with screencapture, and compare against HTML/Figma design specs. Use when user asks to visually verify a macOS app matches its design book, do visual QA, check the app looks right, or compare app vs design."
---

# macOS App Visual QA

## Overview
Systematically compare a running macOS native app against its design spec (HTML prototypes, Figma references, design tokens) by launching the app, capturing screenshots in multiple states, and auditing each design section.

## Prerequisites
- macOS with the app installed or buildable
- Design spec files (HTML previews, Figma PNGs, design token docs)
- Accessibility permissions for AppleScript (`System Events`)

## Procedure

### 1. Locate Design Artifacts
```
glob **/*design*;**/*prototype*;**/*draft*;**/*spec*
glob **/*.fig;**/*.sketch;**/*.png (in design dirs)
```
Read all HTML design previews — they contain exact CSS values (font sizes, weights, opacities, colors, radii, spacing) that ARE the spec.

### 2. Read Implementation Code
Read the UI source files and extract the metrics/tokens enum. Compare token values against the design spec CSS values before even launching the app. This catches numeric mismatches without screenshots.

### 3. Build & Launch the App
```bash
make bundle  # or swift build, xcodebuild
open .build/App.app
```
If build fails (SDK mismatch, etc.), check for a pre-built `.app` in `.build/` or `~/Applications/`.

### 4. Trigger the App via AppleScript
For menu-bar-only apps (LSUIElement agents like Spotlight alternatives), you CANNOT use Cmd+Space reliably (other apps may own it). Instead:

```applescript
-- Click the app's menu bar status item, then its "Show" menu item
tell application "System Events"
    tell process "AppName"
        click menu bar item 1 of menu bar 2
        delay 0.3
        click menu item "Show AppName" of menu 1 of menu bar item 1 of menu bar 2
    end tell
end tell
```

To type into the app:
```applescript
tell application "System Events"
    keystroke "query text"
    delay 1
end tell
```

To use keyboard shortcuts (arrow keys, Cmd+N for filters, Escape):
```applescript
tell application "System Events"
    key code 125  -- Arrow Down
    keystroke "2" using command down  -- Cmd+2
    key code 53   -- Escape
end tell
```

### 5. Capture Screenshots
```bash
screencapture -x /tmp/app-state-name.png
```
The `-x` flag suppresses the shutter sound. Capture these states at minimum:
- **Empty/idle** — just the search bar / initial state
- **Populated** — with a query showing results
- **Selection** — arrow to different rows to see selection highlight
- **Filtered** — click filter chips to see filtered results
- **Empty filter** — select a filter with 0 results
- **Special rows** — calculator, web, assistant, settings (whatever the app has)

### 6. View & Compare
Use `read /tmp/app-state.png` to view each screenshot inline. Open the HTML prototype in the headless browser for side-by-side:
```
xd://browser open file:///path/to/prototype.html
xd://browser run — type queries, take screenshots
```

Also view Figma reference PNGs with `read`.

### 7. Systematic Audit
For each design spec section, check:
- **Typography**: font size, weight, opacity — compare CSS values to Swift/code constants
- **Spacing**: padding, gaps, heights — compare px/pt values
- **Colors**: tint colors, opacity levels, background fills
- **Corner radii**: panel, rows, tiles, chips — check concentric math
- **States**: selected, hovered, Top Hit, empty, loading, error
- **Accessibility**: Reduce Motion, Reduce Transparency, Increase Contrast paths
- **Glass/Material**: Liquid Glass on macOS 26+, fallback on older OS

### 8. Report Format
Use a table per design section:
| Spec | Design value | Code value | Screenshot | Verdict |
Present final summary as pass/fail per section.

## Gotchas
- **Hotkey conflicts**: Cmd+Space often owned by Spotlight; Option+Space by Raycast. Use menu bar AppleScript instead.
- **Chronicle**: If available, use `$TMPDIR/chronicle/screen_recording/*-latest.jpg` for quick screen checks, but `screencapture -x` gives higher resolution.
- **Multiple instances**: Kill duplicates with `kill PID` before testing.
- **Build failures**: Check for SDK/toolchain version mismatches. A pre-built binary in `.build/` may still work.
- **SwiftUI animations**: Disable with `.transaction { $0.animation = nil }` checks — selection should be instant per most specs.
