---
name: xmd-release-bench-harness
description: "Run and extend the xmd Release-flow deterministic bench harness (autoresearch.sh): leg contracts, truth-oracle rules, common wiring pitfalls, and live CDP deploy/log verification for the debug Chrome on port 9222"
---

# xmd Release bench harness — extending & debugging

Procedures for `/Users/martinfan/devv/xediadownloader`'s deterministic Release-flow
benchmark (`autoresearch.sh` → `bun bench/release-bench.ts`) and its live CDP
verification. Read alongside `docs/testing/release-bookmarks-diagnosis.md` (failure
taxonomy) and `docs/plans/2026-08-23-release-history-list-spec.md`.

## Running

```bash
bash autoresearch.sh        # prints METRIC lines; exit 0 iff all legs reach a verdict
bun bench/release-bench.ts  # same thing directly
```

Legs live in `bench/release-bench.ts` (score()); fixtures + fake browser world in
`bench/fixtures.ts`. Deterministic: VirtualClock, no network, no wall clock.

## Harness invariants (breaking these costs hours)

- **Truth lives OUTSIDE the DOM** (`FakeXWorld.truth`). Only a fired optimistic control
  flip marks a scope cleared; node detachment/recycling never does. DOM absence cannot
  distinguish "row recycled" from "server-side removed" — never use DOM presence as the
  oracle for detach cases.
- **Deferred contract for 'gone' detachments**: verdict ok:true is legal ONLY with the
  recheck watchdog armed (`world.flipArmed(id, scope)` via the clearer's onFlip port).
  Wire onFlip in `handleClear`, not just recordFlip.
- **drive() must flush microtasks before declaring deadlock**: the broadcaster resolves
  non-clock promises (fake ports) between clock jobs. Pattern:
  `await tick(); if (!clock.pending) { await tick(); if (!settled && !clock.pending) throw }`.
- **score() owns the clock** — pass it INTO `makeWorld(clock)`; worlds constructed with
  an undefined clock fail later as `this.clock.sleep is undefined` inside clearScope.
- **Release-tab routing**: `sendTabMessage(RELEASE_TAB_ID)` must be routed to the
  permalink window explicitly; list-tab lookup misses it and every probe counts as
  `threw` → `reason=unreachable`.
- **Receiver semantics**: `onScope = clearableScope(pathname, doc) ?? req.asPageScope ?? null`
  (pin is a FALLBACK for pages owning no scope, never an override).
- happy-dom → lib-DOM friction: cast once at the boundary (`asDom<T>()`); declare
  TweetSpec optionals as `Membership | undefined` under exactOptionalPropertyTypes.
- Adding legs changes the rate denominator — fine after all-correct baseline; note it.

## Live CDP verification (debug Chrome, port 9222)

- Chrome Beta runs `--remote-debugging-port=9222 --load-extension=.output/chrome-mv3`
  with profile `~/Library/Application Support/xmd-debug-profile`. Use `localhost:9222`;
  raw `127.0.0.1` fails (binds ::1).
- **Do NOT attach to the first `service_worker` target in /json/list** — MV3 workers
  sleep and other extensions (e.g. NotebookLM Porter) appear there. Attach to the
  extension's OPTIONS PAGE instead (stays alive) and evaluate there; open fresh via
  `PUT http://localhost:9222/json/new?chrome-extension://<id>/options.html` after
  reloads. xmd id lives in the options tab URL (ejbfndjdeemmhccclagchbdbkinepoof).
- Durable log: `chrome.storage.local.get('releaseDiagnostics')` → `{events[1000],
  appended, evicted}`. Worklist: key `clearWorklist`. Snowflake sanity:
  `(BigInt(id) >> 22n) + 1288834974657n` must land within [2010, now+1d].
- Deploy a rebuilt bundle: `bun run build`, then evaluate `chrome.runtime.reload()`
  in the options page over CDP; verify worklist/diagnostics survive and the SW target
  reappears. Verify fixes compiled in by grepping `.output/chrome-mv3/**` for string
  literals (e.g. `reresolved`, `1288834974657`) — identifiers are minified away.
