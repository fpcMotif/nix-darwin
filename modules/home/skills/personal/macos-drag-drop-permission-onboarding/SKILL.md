---
name: macos-drag-drop-permission-onboarding
description: "Implement macOS drag-and-drop permission granting (Full Disk Access, Accessibility) into System Settings via floating guidance HUD, bundle fileURL drag payload, and live TCC polling"
---

# macOS Drag-and-Drop Permission Onboarding

Pattern for implementing fluid, 1-gesture permission granting on macOS (Full Disk Access, Accessibility) where Apple's TCC subsystem does not provide a standard programmatic modal request API.

## Why Drag-and-Drop?

On macOS (macOS 13 Ventura through macOS 27+), Full Disk Access (`kTCCServiceSystemPolicyAllFiles`) and Accessibility cannot be requested via a system prompt sheet. If an app only opens System Settings, the user is faced with finding `+`, authenticating, navigating through `NSOpenPanel`, finding the `.app` bundle, and toggling it.

macOS System Settings' `NSTableView` / SwiftUI list in `Privacy & Security` natively accepts file drops (`public.file-url` / `kUTTypeFileURL`). When an application bundle (`.app`) is dropped into the table, macOS:
1. Prompts for Touch ID / administrator credentials.
2. Adds the application bundle to the list.
3. Automatically enables the toggle to "Allowed".

## Architecture

### 1. Direct Settings Deep Links
- Full Disk Access: `x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles` (Fallback: `x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`)
- Accessibility: `x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility` (Fallback: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`)

### 2. Floating Guidance HUD (`NSPanel`)
- Subclass `NSPanel` with style mask `[.borderless, .nonactivatingPanel]`.
- Window level: `.floating` (or `.popUpMenu`) so it floats over System Settings without stealing active keyboard focus.
- Appearance: transparent background (`isOpaque = false`, `backgroundColor = .clear`), rounded continuous corners (18pt), visual effect material backing.
- Header: `"↑ Drag <App> into the <Permission> list"` with a close button (`✕`).

### 3. Draggable Application Card
- Display app icon, application display name, and a drag affordance handle (`line.3.horizontal`).
- Drag payload: vend `Bundle.main.bundleURL` with `NSPasteboard.PasteboardType.fileURL` / `UTType.fileURL` (`public.file-url`).
- In SwiftUI: `.draggable(Bundle.main.bundleURL)`.
- In AppKit: override `mouseDragged(with:)` and call `beginDraggingSession(with:items:event:)` using `NSPasteboardItem` with `fileURL`.

### 4. Live Authorization Polling & Auto-Dismissal
- Start a ~500ms `Timer` and register for `NSApplication.didBecomeActiveNotification` and `NSWorkspace.didActivateApplicationNotification`.
- Probe for Full Disk Access:
  ```swift
  enum FullDiskAccessProbe {
      static func isGranted() -> Bool {
          let probeURL = FileManager.default.homeDirectoryForCurrentUser
              .appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")
          do {
              let handle = try FileHandle(forReadingFrom: probeURL)
              try? handle.close()
              return true
          } catch {
              return false
          }
      }
  }
  ```
- Once `isGranted()` evaluates `true`:
  - Animate guidance HUD to success state (`"Permission Granted ✓"`).
  - Stop polling ticker.
  - Automatically dismiss floating panel after ~1.5s.
  - Refresh the main configuration/onboarding session state in real time.
