---
name: agent-browser-cdp-a11y
description: "Audit Chrome extension pages (popup.html, options.html) for WCAG 2.1 AA accessibility using agent-browser over CDP port 9222"
---

# Chrome Extension Accessibility Audit using agent-browser over CDP

## Overview

Use `agent-browser@0.33.2` over Chrome DevTools Protocol (CDP port 9222) to audit Chrome Extension pages (`popup.html`, `options.html`) for WCAG 2.1 AA accessibility compliance with embedded `axe-core 4.12.1`.

## Step-by-Step Audit Procedure

### 1. Fetch Browser WebSocket URL
Query `9222/json/version` to get the live browser-level WebSocket URL:
```bash
curl -s http://[::1]:9222/json/version
```
Extract `webSocketDebuggerUrl` (e.g., `ws://[::1]:9222/devtools/browser/<HASH>`).

### 2. Identify Extension ID
Open `chrome://extensions` or inspect the manifest/service worker:
```bash
bunx agent-browser@0.33.2 --cdp "ws://[::1]:9222/devtools/browser/<HASH>" open "chrome://extensions"
bunx agent-browser@0.33.2 --cdp "ws://[::1]:9222/devtools/browser/<HASH>" snapshot
```
Locate the extension ID (e.g., `ooigmlecjgnbiicjbkkecflhgikaoiop`).

### 3. Open Extension Pages and Verify URL
Open `popup.html` and `options.html` directly in the browser session, verifying the URL before auditing:
```bash
bunx agent-browser@0.33.2 --cdp "ws://[::1]:9222/devtools/browser/<HASH>" open "chrome-extension://<EXTENSION_ID>/popup.html"
bunx agent-browser@0.33.2 --cdp "ws://[::1]:9222/devtools/browser/<HASH>" get url
```

### 4. Run `a11y --json` Audit
Run the embedded `axe-core` audit and extract violations:
```bash
bunx agent-browser@0.33.2 --cdp "ws://[::1]:9222/devtools/browser/<HASH>" a11y --json | jq '{url: .data.url, counts: .data.counts, violations: .data.violations, incomplete: .data.incomplete}'
```

### 5. Verify Incomplete Color Contrast Checks
For any items flagged under `incomplete` for `color-contrast`:
- Calculate the contrast ratio between foreground text and composite background color.
- Verify text smaller than 18pt (24px) meets the WCAG 1.4.3 Level AA minimum contrast ratio of **4.5:1**.
