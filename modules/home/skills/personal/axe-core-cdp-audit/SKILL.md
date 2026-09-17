---
name: axe-core-cdp-audit
description: Run axe-core WCAG 2.0/2.1 AA accessibility audit on pages via Chrome CDP
---

# Axe-Core CDP Accessibility Audit

Run an industry-standard axe-core (WCAG 2.0 / 2.1 AA) accessibility audit on Chrome extension pages or web applications via Chrome DevTools Protocol (CDP port 9222).

## Procedure

1. Obtain the WebSocket debugger URL for the target page from `http://127.0.0.1:9222/json/list` (or `http://[::1]:9222/json/list` if Chrome is bound to IPv6).
2. Download or read `axe.min.js` (e.g., v4.10.2 from cdnjs).
3. Connect to the WebSocket debugger URL and evaluate `axe.min.js` on the target page.
4. Execute `axe.run(document, { runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa'] } })` and collect `violations`, `passes`, and `incomplete` results.
5. Report the number of passes, incomplete items, and violations with exact node selectors and descriptions.
