---
name: chrome-extension-remote-cdp
description: "Inspect and visually verify an unpacked Chrome extension through a user-provided remote CDP endpoint, especially its options page."
---

# Remote-CDP Chrome extension verification

Use when the user has launched Chrome with remote debugging (commonly `http://127.0.0.1:9222`) and an unpacked extension is already loaded.

1. Connect with `xd://browser` using `action: "open"` and `app.cdp_url`. Then use `tab.goto(...)` inside `action: "run"`; the initial `open` may leave the tab at its prior URL.
2. Go to `chrome://extensions/` and inspect with `tab.observe()`.
3. Get the extension ID from the Extensions page through `tab.evaluate(...)`, walking Chrome's shadow DOM from `extensions-manager` to `extensions-item` and matching the extension name. Do not hard-code an ID.
4. Navigate directly to the extension page, for example `chrome-extension://<extension-id>/src/options/index.html`.
5. For DOM inspection, use `tab.evaluate(...)`, not the raw `page.evaluate(...)` scope: in a remote connection the latter can refer to a stale/different target.
6. Use normal `tab.click(...)` after `tab.scrollIntoView(...)`. If CDP reports an in-viewport button as hidden or covered, inspect its selector and invoke that exact button's native `.click()` through `tab.evaluate(...)`; this still exercises the app's real event listener.
7. Verify the changed behavior using the rendered DOM/accessibility tree and capture a screenshot for visual evidence. Preserve user data; do not clear or mutate extension storage unless the task explicitly requires it.

Example inspection of visible external links:

```ts
await tab.evaluate(() =>
  [...document.querySelectorAll('a')]
    .filter((link) => (link.textContent ?? '').startsWith('Open'))
    .map((link) => ({
      text: link.textContent,
      href: link.getAttribute('href'),
      target: link.getAttribute('target'),
    })),
);
```
