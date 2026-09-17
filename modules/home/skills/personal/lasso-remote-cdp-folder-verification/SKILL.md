---
name: lasso-remote-cdp-folder-verification
description: "Verify the built Lasso extension's Folder cards through a Chrome remote CDP session, including reloading the unpacked extension and forcing lazy media previews to load."
---

# Lasso Folder verification through remote CDP

Use when validating the built extension against a user-provided Chrome remote-debugging endpoint (commonly `http://127.0.0.1:9222`).

1. Build first: `bun run build`.
2. Connect with the `browser` device using `app.cdp_url`; do not navigate an unknown user tab.
3. Reload the unpacked extension from `chrome://extensions/` through nested shadow roots:
   - `extensions-manager` shadow root
   - `extensions-item-list` shadow root
   - extension item `#ofigheafkelcnoocplblehkdcfoafkld`
   - `#dev-reload-button`
4. Browser named tabs can detach after an extension reload. Create an isolated page through raw Puppeteer (`browser.newPage()`), navigate it to:
   `chrome-extension://ofigheafkelcnoocplblehkdcfoafkld/src/options/index.html`
5. In the isolated page, click `button[aria-label="Browse Saved"]` via DOM evaluation. Do not rely on the browser helper's element-id click for this control; it can be blocked by overlays.
6. Bring the isolated page to the front before judging lazy images. A background page reports `document.visibilityState === "hidden"` and `loading="lazy"` previews will remain unloaded.
7. Assert both semantic output and pixels:
   - Folder links have the expected source-specific labels.
   - Expected media `<img>` elements have `complete === true` and `naturalWidth > 0`.
   - Capture a screenshot from the isolated Puppeteer page to a temporary path, then inspect it with `read`.

Keep validation non-destructive: inspect IndexedDB only when necessary, never rewrite user saved-post records during a visual check.
