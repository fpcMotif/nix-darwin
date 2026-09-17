---
name: labs-google-live-parity
description: "Measure and improve pixel parity between a local clone and the live labs.google page: exhaustive DPR2 study captures, deterministic frame-by-frame motion recording, and video-synced pixel diffs over raw-CDP Chrome."
---

# Live-page parity: studying labs.google and measuring a clone against it

Procedure for measuring how closely a local clone matches the LIVE labs.google
page — exhaustive visual ground truth first, then frame-by-frame motion capture,
then synced pixel-diffs. Built in /Users/martinfan/devv/googlelab-cc
(tools/study-capture.mjs, tools/record-frames.mjs, tools/bench-pixel-fidelity.mjs).

## Services

- Preview of the clone: `bunx vite preview --host 127.0.0.1 --port 5188 --strictPort`
  (run under a supervisor — backgrounded processes from a shell call die with it).
- Chrome headless on CDP port 9334:
  `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless=new
  --remote-debugging-port=9334 --user-data-dir=$(mktemp -d) --disable-gpu
  --hide-scrollbars --mute-audio --force-device-scale-factor=1 --window-size=1568,908
  --lang=en-US about:blank`
- Raw-WebSocket CDP client pattern lives in tools/bench-pixel-fidelity.mjs
  (connectResilient: retries the debugger handshake; fail-all-on-close; 30s timeouts).

## Pitfalls (all hit for real)

- Headless Chrome EXITS (code 0) when its last tab closes. Scripts that close their
  own tab kill the browser; keep a guard tab or expect the exit.
- `PUT /json/new?<encoded-url>` can land OFF the target app. Always open
  `about:blank`, then `Page.navigate` to the URL.
- labs.google's Lottie splash never completes under headless SwiftShader — hide
  `.loading-container` (display:none) before shooting or it covers every frame.
- Regex literals inside template literals sent via Runtime.evaluate lose backslashes
  (`\(` -> `(`). Interpolate `new RegExp(JSON.stringify(re.source))` instead.
- A CSS-transition/animation seek must be ABSOLUTE-from-start and applied promptly;
  a resolved interaction point recorded into meta.json must never double as an
  execution gate (replays skip the interaction).
- Concurrent editors WILL touch the same harness files. Re-read immediately before
  every edit; anchor edits on fresh file tags only.

## Study capture (design/interface ground truth)

`node tools/study-capture.mjs --target labs --out probe/study/labs`

Captures ~58 DPR2 shots: entrance sequence (fresh load per frame), scroll sweep,
hero floating-card hovers + CTA spring samples, card-hover reveals, pill hovers,
each category click END STATE, the flip choreography frame-by-frame (60..1400ms),
story-card hover, falling-element grab/drag/throw, footer hover, full-page composites
@ DPR1+DPR2 (captureBeyondViewport). Read probe/study/labs/fullpage/fullpage-dpr1.png
FIRST — it reveals structural gaps (missing sections) that per-keyframe numbers hide.

## Frame-by-frame motion recording

`node tools/record-frames.mjs --url U --out DIR --t0 600 --t1 3000 --step 100
[--scrollY Y] [--hoverText S | --hoverX N --hoverY N --hoverAtMs M]`

One page load; a virtual clock (performance.now + rAF timestamps step in exact
16.67ms increments) is steered per frame by raising `window.__PARK_AT`; every
`document.getAnimations()` entry is paused and seeked to the same absolute time.
Identical timestamps on two pages = directly comparable frames.

## Parity measurement (clone vs live)

1. Shoot both sides at identical viewport/DPR with videos SYNCED:
   pause every `<video>`, set `currentTime` to the same value (race the seeked
   event against a ~1.2s timeout - readyState may be < 1).
2. Pin carousel state on the live side if it auto-advances (click the first dot),
   and shoot fast enough to stay inside one slide window.
3. pixelmatch threshold 0.1; report matching % and write the diff PNG. READ the
   diff PNG: double-vision ghosts = geometry offset (fix padding); solid red
   media regions = wrong slide/frame; thin edge bands on blurred shapes =
   rasterizer noise floor, not a pose change.

Known numbers (1568x908): featured-hero went ~12% -> ~68% parity after porting the
real full-viewport video carousel (4 webm slides + posters served locally, 120px
Google Sans headings, real copy, bar-and-dots progress). Residual dominated by
video content when slides/phases differ, then logo/font deltas.

## Ground-truth extraction quickies

- Slide inventory + copy: `.featured-hero__animation__text-container` nodes hold
  h2 (120px Google Sans 400) + small.subheading (24px) + a.cta per slide.
- Media srcs: filter IMG/VIDEO with rects intersecting the viewport; labs.google
  serves /assets/videos/featured-hero/*.webm and /assets/images/tools/*-poster.webp.
- Progress: bar 135x8 cream rgb(243,239,234) at y=832; arrows 60x60 at x-centers
  620/949, all adjacent in one 389px block centered on the page axis.
