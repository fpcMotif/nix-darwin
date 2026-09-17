---
name: chrome-extension-a11y-audit
description: "Run axe-core WCAG 2.0/2.1/2.2 AA accessibility audit on Chrome extension pages (popup.html, options.html) over CDP port 9222"
---

# Chrome Extension Accessibility (a11y) Audit via CDP Port 9222

Run an automated, full **axe-core v4.10.2** WCAG 2.0 / 2.1 / 2.2 AA accessibility audit on Chrome extension pages (`popup.html`, `options.html`) connected over Chrome DevTools Protocol (CDP) port 9222.

## Prerequisites
- Chrome running with `--remote-debugging-port=9222` (or forwarded via IPv4/IPv6 proxy if Chrome binds to `[::1]:9222`).
- Target extension loaded.

## Execution Workflow

1. Query available CDP targets on port 9222:
   ```bash
   curl -s http://127.0.0.1:9222/json/list
   ```

2. Run the axe-core audit script over CDP WebSocket:
   ```javascript
   // Inject axe-core v4.10.2 script and execute rule tags:
   // ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa']
   const results = await axe.run(document, {
     runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'] }
   });
   ```

3. Report passes, violations, and incomplete items for every target extension page.
