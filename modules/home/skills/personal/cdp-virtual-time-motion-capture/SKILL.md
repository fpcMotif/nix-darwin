---
name: cdp-virtual-time-motion-capture
description: "Record web pages' animation timelines frame-by-frame with deterministic virtual time over raw CDP (Chrome headless): virtual clock shim, per-frame WAAPI seek, interaction keyframes, and the environment pitfalls that silently break such captures."
---

# Deterministic frame-by-frame motion capture over CDP

Record any page's animation timeline as PNG frames where every frame is an agreed
pose across CSS animations, transitions, WAAPI, AND rAF integrators — so two pages
(or two builds) produce directly comparable sequences.

## Core mechanism

1. Inject a virtual clock before any page script (`Page.addScriptToEvaluateOnNewDocument`):
   - `performance.now()` returns virtual time starting at 0.
   - Wrapped `requestAnimationFrame` advances vtime by exact 1000/60ms per real rAF callback.
   - A steerable deadline (`window.__setParkAt(t)`) parks time at t forever once reached;
     raising it resumes the march. Time NEVER advances outside rAF callbacks.
2. Per frame at timestamp t:
   - Raise `__PARK_AT(t)` AND pause+seek every `document.getAnimations()` entry to
     `currentTime = t` (absolute, wall-clock independent).
   - Wait one double-rAF, then `Page.captureScreenshot`.
3. Mid-transition poses: seek only the tracks you classify (e.g. `a.animationName === 'x'`
   or CSSTransition with specific `transitionProperty`) to a relative offset like 45% of
   their duration; everything else clamps to end state. Pin promptly after triggering
   while tracks are still active.

## Interaction keyframes

Resolve text-labeled buttons to viewport coordinates ONCE at reference-capture time and
freeze them into metadata; replays dispatch `Input.dispatchMouseEvent` at stored points.
A resolved point must be PROVENANCE ONLY — never use it as an execution gate, or replays
silently skip the interaction and compare against a mismatched state.

## Environment pitfalls (each cost real debugging time)

- Headless Chrome exits (code 0) when its last tab closes — not a crash. Keep a guard tab
  or spawn Chrome per run.
- `/json/new?<encoded-url>` lands off-app sometimes; prefer opening `about:blank` then
  `Page.navigate` explicitly.
- The DevTools websocket can refuse right after `/json/new` on fresh Chrome: retry connect
  (~6×400ms), add `ws.onclose` fail-all and a 30s per-call timeout, else failures hang as
  unsettled awaits.
- Sites with loading splashes (e.g. Angular Lottie overlays) may never dismiss under
  headless SwiftShader; hide them by class-name convention identically on both sides.
- Regex literals inside JS template literals sent to `Runtime.evaluate` lose backslashes
  (`\(` becomes `(`); interpolate `JSON.stringify(re.source)` into `new RegExp(...)` instead.
- Software-rendered rasterization has a load-dependent antialiasing noise floor on blurred,
  rotating edges (~0.07-0.12% of viewport pixels). Never absorb it by widening the diff
  threshold; characterize it (same-build N captures idle vs loaded) before chasing pose bugs.
- Real sites vs clones: measure the actual gap first (a self-referential frozen screenshot
  proves stability, NOT replication fidelity).

## Reference implementation

`tools/record-frames.mjs` and `tools/bench-pixel-fidelity.mjs` in the googlelab-cc repo
(raw-WebSocket client, resilient connect, clock shim, text-action resolution, fling/hover/
click keyframes).
