---
name: study-first-site-parity
description: "Study-first workflow for replicating an existing website pixel-by-pixel: exhaustive DPR2 capture campaign before coding, real asset extraction, live-target (not self-reference) parity measurement, deterministic CDP frame recording recipes"
---

# Study-first pixel parity for site clones

When asked to replicate an existing page "pixel by pixel", the failure mode is building
from memory/probes of mechanics while content, hero, and hover states silently diverge.
This procedure keeps the work honest.

## Order of operations

1. **Study campaign BEFORE any code** (`tools/study-capture.mjs` pattern): drive the real
   page over CDP and capture exhaustively at DPR 2:
   - entrance sequence (fresh load per frame),
   - scroll sweep every ~400px,
   - EVERY interactive state: per-pill hover AND click end-state (theme swaps!),
     card hovers early+settled, arrow hovers, link hovers,
   - strong effects frame-by-frame (click -> shots at 60..1400ms),
   - fullpage composite via `captureBeyondViewport`.
2. **Extract real assets**: probe DOM for `<video>`/`<img>` srcs inside the target
   surfaces (hero backgrounds are often full-bleed looping webms whose motion graphics
   are baked into the video - the "floating cards" are not DOM elements). Download
   locally so the page renders offline.
3. **Extract exact copy + typography** per slide/section via
   `getComputedStyle` (fontSize/lineHeight/weight/family/color) - do not invent copy.
4. **Port**, then measure parity against the LIVE page capture at matched DPR
   (`pixelmatch` after normalizing sizes). Report % matching per surface.

## Benchmark semantics trap

A harness that compares the clone to a frozen screenshot OF THE CLONE proves only
"nothing changed", never "it matches". If the user asks for real-page parity, the
reference MUST be live-target captures. Expect and report the true gap (a content-diverged
clone can score 80%+ mismatch even when mechanics are faithful).

## Deterministic capture recipes (CDP, raw WebSocket)

- Inject a virtual clock via `Page.addScriptToEvaluateOnNewDocument` BEFORE navigation;
  park-from-first-frame (fixed deadline from load) makes rAF integrators see identical
  timestamp sequences regardless of machine speed. Stepping = raise the deadline.
- Pin CSS/WAAPI separately: pause + set `currentTime` on every `document.getAnimations()`.
  Mid-transition poses: absolute seek from transition start (wall-clock independent).
- Text-labeled interactions: resolve button rects at CAPTURE time, freeze coordinates into
  meta, replay at stored points. Points are provenance - NEVER execution gates (a gate
  serialized into meta makes replays skip the interaction).
- `/json/new?<url>` races: open about:blank then `Page.navigate`. Headless Chrome exits
  when its last tab closes (exit 0) - not a crash.
- Regex literals inside template literals sent to Runtime.evaluate lose backslashes;
  interpolate `JSON.stringify(re.source)` instead.
- SwiftShader (--disable-gpu) rendering is deterministic but load-sensitive: blurred
  rotating edges jitter under concurrent machine load. Characterize the noise floor
  (N same-build runs) before treating small diffs as regressions; never absorb it by
  widening the diff threshold.
- Concurrent editors on harness files are common: re-read + re-anchor tags before every
  edit; verify syntax immediately after each change.
