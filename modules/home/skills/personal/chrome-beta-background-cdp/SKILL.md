---
name: chrome-beta-background-cdp
description: Run Chrome Beta CDP remote debugging entirely in the background on macOS without stealing window focus.
---

# Chrome Beta Background CDP Execution

Guidelines and procedures for executing CDP automation/debugging on Chrome Beta without bringing the browser window to the foreground or stealing focus on macOS.

## Problem
By default, creating new tabs (`/json/new`), navigating pages (`Page.navigate`), or enabling CDP domains (`Page.enable`, `Runtime.enable`) can cause macOS to activate the application and bring Google Chrome Beta to the front, interrupting the user.

## Procedure to Keep Chrome Beta in Background

### 1. Position Window Off-Screen via CDP
Use the browser-level target (`/devtools/browser/...`) or any page target to set the window bounds off-screen:

```ts
const version = await (await fetch("http://127.0.0.1:9222/json/version")).json();
const ws = new WebSocket(version.webSocketDebuggerUrl);
await new Promise(r => ws.onopen = r);

const targets = await (await fetch("http://127.0.0.1:9222/json/list")).json();
const pageTarget = targets.find(t => t.type === "page");

if (pageTarget) {
  const win = await send("Browser.getWindowForTarget", { targetId: pageTarget.id });
  await send("Browser.setWindowBounds", {
    windowId: win.windowId,
    bounds: {
      left: -9999,
      top: -9999,
      width: 1200,
      height: 900,
      windowState: "normal"
    }
  });
}
```

### 2. Set Process Visibility via AppleScript
Hide the "Google Chrome Beta" process on macOS:

```bash
osascript -e 'tell application "System Events" to set visible of process "Google Chrome Beta" to false'
```

### 3. Rules for Focus Suppression
- NEVER call `Page.bringToFront` or `Target.activateTarget`.
- Prefer querying and connecting to existing target IDs from `/json/list` instead of opening new visible tabs.
- When querying extension content script isolated worlds, resolve the execution context via `Runtime.executionContextCreated` matching the extension ID or name, then evaluate using `contextId`.
