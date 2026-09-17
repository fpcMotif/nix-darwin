---
name: lasso-convex-sync-cdp-diagnosis
description: "Diagnose Lasso extension Convex sync failures live via CDP: compare chrome.storage.local config vs deployment LASSO_DEVICE_KEY, probe /api/query from the options page, restore connectivity; includes rotation hazards and macOS CDP launch quirks."
---

# Lasso Convex sync "Test connection" failure — live CDP diagnosis

Verified end-to-end 2026-08-23 on deployment silent-crab-355 (Chrome 151, MV3).

## Root cause class
Device-key mismatch. Server gate `convex/lib/auth.ts::assertDeviceKey` compares `args.deviceKey` against env `LASSO_DEVICE_KEY`; mismatch throws `Unauthorized: invalid device key`, which the options UI renders as `CONVEX_TEST_ERROR` "Connection failed. Check the URL and device key.". Transport/CORS/deployment were healthy in every observed failure.

## Diagnosis recipe
1. **Browser-side truth**: options page persists config at `chrome.storage.local` key `"lasso:settings"` → fields `convexUrl` / `convexDeviceKey`. Read via CDP `Runtime.evaluate` → `chrome.storage.local.get("lasso:settings")`. A controlled input's `.value` can look updated without storage being saved — verify storage AFTER a full `Page.reload`, not just the DOM.
2. **Server-side truth**: `bunx convex env get LASSO_DEVICE_KEY` in the project dir. NEVER print either secret; compare programmatically (`a === b`, lengths).
3. **Transport probe** (run from the options page's execution context to also validate extension-origin CORS): `fetch(url + "/api/query", {method:"POST", headers:{"Content-Type":"application/json"}, body: JSON.stringify({path:"membership:catalog", args:[{deviceKey:"<k>"}], format:"convex_encoded_json"})})`. HTTP is 200 even on auth failure; read `status` (`success|error`) and `errorMessage` (names `assertDeviceKey`). Plain curl also works — Convex CORS echoes any origin incl. `chrome-extension://`.
4. **Fix**: set the identical pair on both sides → **Test connection** → "Connected".

## Rotation hazard
Changing env `LASSO_DEVICE_KEY` instantly invalidates EVERY Chrome installation still holding the old value — a later "failure" is then expected, not a user typo. Rotate only deliberately; update all installations afterward; never echo old/new secrets.

## CDP environment quirks (macOS)
- Port 9222 dead usually means the user's Chrome runs without `--remote-debugging-port`. Graceful quit (`osascript -e 'quit app "Google Chrome"'`) can BLOCK on dialogs — poll `pgrep -x "Google Chrome"`; if still running, do NOT kill the user's browser. Launch a second instance instead: `hub start "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --user-data-dir=/tmp/lasso-cdp-profile --remote-debugging-port=9222 --no-first-run about:blank` (Chrome 136+ refuses debug ports on the default profile dir).
- Seeding the clone with the user's session: copy `~/Library/Application Support/Google/Chrome/Local State` + `Default/Cookies*` into the clone dir. VERIFIED LIMITATION: x.com login does NOT survive the copy (session-scoped cookies) → login redirect; fall back to fixture-first testing rather than fighting auth.
- `bunx agent-browser`: `connect 9222` → `open <url>` → `wait <ms>` → `get url` → `eval "<js>"`.
- Duplicate "Lasso settings" targets can appear in `/json/list`; disambiguate by target id/title before driving the page.
