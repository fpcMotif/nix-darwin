---
name: xmd-release-cdp-diagnosis
description: "Inspect and hot-deploy the xmd extension Release flow over CDP port 9222: read durable diagnostics/worklist from the options page, probe live x.com history-page DOM, rebuild-and-runtime.reload the unpacked extension"
---

# Live CDP diagnosis of the XMD Release flow

Procedure for inspecting why Release/Clear fails on x.com using the debug Chrome
that runs the unpacked extension. All facts below verified 2026-08-23.

## Environment facts

- Debug Chrome Beta runs with `--remote-debugging-port=9222`,
  `--user-data-dir=~/Library/Application Support/xmd-debug-profile`,
  `--load-extension=<repo>/.output/chrome-mv3`.
- The port answers on `http://localhost:9222` / IPv6 `[::1]`; plain
  `127.0.0.1` gets connection-refused (see `chrome-cdp-ipv6-proxy` skill).
- Extension id of X Media Downloader in that profile: `ejbfndjdeemmhccclagchbdbkinepoof`.
  Beware: other extensions (e.g. NotebookLM Porter) also expose service workers on
  `/json/list` — verify identity with `chrome.runtime.getManifest().name` before use.

## Reading the durable Release log (the main evidence source)

The MV3 SW sleeps, so attach to an OPEN extension page instead — the Options tab
(`chrome-extension://<id>/options.html`) shares the origin and storage:

```js
const targets = await (await fetch('http://localhost:9222/json/list')).json();
const opts = targets.find(t => t.type === 'page' && t.url.includes('options.html'));
const ws = new WebSocket(opts.webSocketDebuggerUrl); /* then Runtime.evaluate */
await evalOpts(`chrome.storage.local.get(null).then(v => Object.keys(v))`);
// keys: clearWorklist, releaseDiagnostics {appended, events[1000], evicted}, settings
```

- `releaseDiagnostics.events` — last 1000 clear events. Stage vocabulary and the
  five failure causes are documented in `docs/testing/release-bookmarks-diagnosis.md`.
- `clearWorklist` — seeded posts + latch states; all-sane ids expected.
- Snowflake sanity: real id decodes to `(BigInt(id) >> 22n) + 1288834974657n`
  inside [2010-11-04, now]. A decoded date outside that window = junk id; X 404s
  its permalink forever and the release leg burns its poll budget.

## Live DOM contract probes (read-only)

A tab parked on the surface under test usually exists; reuse it, never bringToFront:

```js
const pages = await browser.pages();               // omp browser device, cdp_url http://localhost:9222
const page = pages.find(p => p.url().includes('x.com/i/history'));
```

Verified contract on `/i/history` (Bookmarks/Likes merged surface):
- Rows: `article[data-testid="tweet"]` inside `div[data-testid="cellInnerDiv"]`;
  ids resolve via own `a[href*="/status/"]` links (not inside quoted cards).
- Controls unchanged: active `removeBookmark`/`unlike`, cleared `bookmark`/`like`.
- Tabs are anchors: `/i/history` (Bookmarks), `/i/history/likes` (Likes).
- Permalink error shell carries `[data-testid="error-detail"]`.

## Deploying a rebuilt bundle into the running debug Chrome

1. `bun run build` (writes `.output/chrome-mv3`).
2. Over the options-page socket: `chrome.runtime.reload()`.
3. Reload tears down extension pages — reopen options via
   `PUT http://localhost:9222/json/new?chrome-extension://<id>/options.html`.
4. Verify: SW target reappears in `/json/list`; `chrome.storage.local.get`
   still returns worklist/diagnostics; grep `.output/chrome-mv3/**/*.js` for the
   fix's string literals to confirm the new code shipped.

## Gotchas

- `chrome.storage.session` is empty for this extension; everything durable lives
  in `storage.local`.
- The MV3 SW target disappears when idle — wake it by opening/reloading any
  extension page rather than hunting `/json/list`.
- Never click/mutate on live x.com during diagnosis; DOM reads and storage reads only.
