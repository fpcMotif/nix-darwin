---
name: xmd-release-diagnosis-and-bench
description: "Diagnose xmd extension Release/Clear failures via CDP port 9222 (durable releaseDiagnostics log, snowflake ID math) and validate fixes with the deterministic 9-leg autoresearch benchmark"
---

# xmd Release flow — live diagnosis + benchmark loop

Repeatable procedure for diagnosing Release/Clear failures in this repo (WXT MV3 extension that un-bookmarks/un-likes X posts) and validating fixes against the deterministic bench.

## 1. Connect to the debug Chrome
- Chrome Beta runs with `--remote-debugging-port=9222 --user-data-dir=.../xmd-debug-profile --load-extension=.output/chrome-mv3`.
- Reachable at `http://localhost:9222` ONLY (IPv6 bind; `127.0.0.1` refuses). If missing: relaunch with those flags from repo root.
- List targets: `curl http://localhost:9222/json/list`. Prefer existing tabs (one usually sits on `x.com/i/history`); never close CDP-connected pages.

## 2. Read the durable diary (releaseDiagnostics)
- The MV3 service worker sleeps; do NOT attach to it. Use the open `options.html` page target instead — same extension origin, same storage.
- WebSocket → Runtime.evaluate → `chrome.storage.local.get('releaseDiagnostics')`. Shape: `{appended, evicted, events:[≤1000]}`. Events: `{t, source:'clear'|'background', stage, tweetId?, detail}`.
- Stage vocabulary (keep stable; consumers grep it): `clear-seeded, clear-claim, clear-settle, clear-dispatch, clear-release-scope, clear-release-poll (probes/threw/reloaded/elapsedMs/reason=mounted|exhausted|unreachable|nav-failed|page-error|backoff), clear-flip (+clear-flip-fabricated), clear-already-cleared, clear-attempt-fail, clear-recheck, clear-tab-error, clear-resolve`.
- Full failure→line mapping lives in `docs/testing/release-bookmarks-diagnosis.md`.

## 3. Known failure classes (as of 2026-08)
- Garbage seeded id: decode snowflake `(BigInt(id)>>22n)+1288834974657`; outside [2010, now+1d] ⇒ permalink 404s forever. Gate = `isClearableTweetId` (clearer.ts).
- Detach-as-proof fabrication: virtualizer recycles captured node mid-poll while post still member. Verdict rule: detached arm requires fresh re-resolve `cleared`; `gone` defers to recheck watchdog (onFlip must fire); `member`/`ambiguous` refuse.
- History surface: Bookmarks=`/i/history`, Likes=`/i/history/likes` (plain anchors). DOM contract unchanged (`article[data-testid=tweet]`, `removeBookmark⇄bookmark`, `unlike⇄like`).

## 4. Run the bench
- `bash autoresearch.sh` → runs `bun bench/release-bench.ts` (9 legs, happy-dom fixtures + VirtualClock, zero network). Prints `METRIC` lines; exit 0 required.
- Legs S1–S9: history bookmarks/likes sweeps, allLists cross-list, late-mount permalink, never-mounts, detach-gone (deferred contract: ok only if world.flipArmed), detach+remount-member (must refuse), seed-gate integration via real `planClearSeed` (doomed_seeds), orphan-skip after 2 no-receiver dispatches.
- Fixture ground truth is OUTSIDE the DOM (`FakeXWorld.truth`) — DOM absence ≠ cleared. Keep it that way.
- Full gate before logging a keep: `bun run check`.

## 5. Deploy verification
- `bun run build` rebuilds `.output/chrome-mv3`; verify fix strings survived minification (`grep -rl 1288834974657 .output/chrome-mv3`).
- Hot-reload over CDP: evaluate `chrome.runtime.reload()` in any extension page → SW restarts, worklist/diagnostics persist. Re-open options.html if the reload closed it.

## Gotchas
- A second actor commits concurrently in this repo — expect scope-deviation warnings on `log_experiment`; pass `justification`.
- Scout subagent type fails fast here (Cloud Code Assist rejects tool schema) — read files directly instead.
