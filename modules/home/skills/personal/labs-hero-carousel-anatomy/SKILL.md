---
name: labs-hero-carousel-anatomy
description: "Measured anatomy of labs.google's featured-hero video carousel and its GSAP rebuild pattern: blob-expand handoff transition, video-backed slides, progress-fill-driven auto-advance, and the determinism rules that make it screenshot-testable. Use when working on googlelab-cc / googlelab-cc-gsap hero code or porting more of the page to GSAP."
---

# labs.google featured-hero carousel — measured anatomy + GSAP rebuild pattern

## Real site mechanics (measured frame-by-frame, 2026-08)

- Hero = featured-experiment **video carousel**: each slide streams its own AI-generated footage from `https://labs.google/assets/videos/featured-hero/*.webm` (Flow Music, Google Flow, Pomelli, Stitch; muted/loop/autoplay/playsInline, `object-fit: cover`, NO filter/transform on the element — blur lives in the footage).
- Transition anatomy (3 layers, ~1.1s total):
  1. Text crossfades IN PLACE (outgoing + incoming overlap at same position)
  2. A dark rounded-hexagon panel scales up from center over the handoff; incoming title readable ON the panel
  3. Panel recedes as background footage crossfades; progress fill restarts
- Auto-advance driven by a `width` CSSTransition progress pill (`featured-hero__progress-fill`); prev/next arrows + dot pagination.
- Floating SVG shapes use the same `gl-float-x/y/r` three-track system (`animation-composition: add`) the rebuild already replicates.
- NO WebGL/shaders in page code — "shader look" is inside Google's licensed videos.

## GSAP rebuild pattern (googlelab-cc-gsap `FeaturedHero.tsx`, commit 95aa285+)

- One `gsap.timeline` per handoff: outgoing text fade (`power1.in` @0.08) ∥ blob scale-up (`power3.in` @0) → incoming text fade-in @0.4 → blob recede (`power2.out` @0.62).
- Blob = SVG rounded-hexagon path scaled from 0.12 to viewport-cover (`max(vw,vh)*1.35/baseSize`); z-order: outgoing text < blob < incoming text.
- **Progress fill drives auto-advance**: transform-based `scaleX` tween, `onComplete → goTo(next)` — never animate layout `width`.
- Video layers stacked full-bleed, always playing; crossfade opacity on slide change.
- `prefers-reduced-motion`: instant swap via matchMedia guard.
- Assets © Google — study-only local rebuild, not for redistribution.

## Determinism contract (benchmark-critical — see also autoresearch notes in session)

- Injected virtual clock BEFORE any page script: rAF timestamps AND `performance.now()` advance in exact 1000/60ms steps from 0, park at SEEK_T via `window.__PARK_AT`. GSAP freezes automatically (reads performance.now); app exposes `window.__MOTION_SEEK(ms)` to hard-pause + re-render every registered card.
- CSS/WAAPI animations pinned separately: population-stable sweeps — pause+seek repeatedly until `document.getAnimations().length` stops changing, THEN park. Single-sweep misses late-born transitions (IO entrances, hover spawns under load) which keep running live against the parked clock.
- **All input/gesture/settle timing uses fixed virtual-frame waits, NEVER wall-clock sleeps** — real sleeps feed scheduler jitter into release velocity (fling snap detent: 11% replay miss) and transition-set genesis races (mid-pose self-diff). Pattern: `waitFrames(n)` helper awaiting n rAFs.
- JS springs/physics must be clock-pure: catch-up integration in capped 1/30s substeps so pose = pure function of elapsed time (visibility-timing lotteries otherwise bake nondeterministic piles into captures).
- CSS `visibility: hidden` on a wrapper hides descendants even when GSAP sets `visibility: inherit` on them — control hidden state via GSAP `autoAlpha` on the wrapper itself.
- `vite preview` binds ::1 by default: pass `--host 127.0.0.1`.

## Known hazards in this repo

- Concurrent editor saves clobber working-tree changes between read and edit (happened 5× in one session): re-read before every edit; md5-stability-check before benchmarking after foreign edits; commit immediately after verified work.
- References must be regenerated through `./autoresearch.sh capture-ref` whenever input protocol OR app timing changes; capture and replay share one code path by design.
- Residual ≤0.4% replay scatter under machine load is named per-keyframe by the double-capture self-diff column (`METRIC nondet_worst_pct`) — fix protocols, never widen thresholds to absorb it.
