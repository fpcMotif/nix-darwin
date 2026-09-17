---
name: deterministic-motion-screenshot-bench
description: "Build deterministic frozen-time screenshot benchmarks for animated web apps (CSS/WAAPI + rAF + GSAP): virtual clock injection, population-stable animation pinning, virtual-frame gesture spacing, double-capture nondeterminism tripwire."
---

# Deterministic screenshot benchmark for animated web apps

Procedure for pixel-stable captures of a page whose motion is driven by CSS animations/transitions, rAF loops, and/or GSAP — so that visual-regression diffs measure real changes, not scheduler luck. Derived the hard way on a labs.google-style rebuild (see repo harness `autoresearch.sh` + `tools/bench-pixel-fidelity.mjs`).

## Core protocol

1. **Virtual clock, injected pre-document** (`Page.addScriptToEvaluateOnNewDocument`):
   - Wrap `requestAnimationFrame`: deliver timestamps advancing exactly 1000/60ms per scheduled frame from 0.
   - Replace `performance.now` with the same virtual time (GSAP reads it → freezes automatically).
   - Park semantics: when `window.__PARK_AT` is set and vtime ≥ parkAt, every callback fires with EXACTLY parkAt forever (loops keep spinning on a constant clock — never deadlock an awaited rAF).
2. **Freeze order per keyframe**: navigate fresh → settle (scrollHeight stability poll + `document.fonts.ready`) → scroll to offset → optional hover/click input → pause+seek every `document.getAnimations()` entry to SEEK_T → set `__PARK_AT = SEEK_T` → double-rAF → screenshot.
3. **Population-stable pinning**: late-born transitions (IO entrances, hover spawns) miss a single sweep. Loop: enumerate getAnimations, pause+seek all, one rAF, repeat until count stops changing (≤8 rounds); only then park. Skipping this leaves ~0.1-0.4% noise that lands on RANDOM keyframes.
4. **Gesture inputs must be spaced by virtual frames, never wall-clock sleeps** — fling/drag release velocity feeds snap detents or spring states; real sleeps feed scheduler jitter straight into the pose. Helper: `waitFrames(cdp, n)` evaluating N awaited rAFs. Post-gesture settle also in frames (e.g., 90f ≈ 1.5s) so JS springs converge inside a fixed virtual budget.
5. **Mid-pose captures**: pin selected tracks (keyframe animations + transitions on specific properties) at an ABSOLUTE currentTime offset from their own start (e.g., 405ms), everything else at SEEK_T. Commit tracks first with ~3 virtual frames, then pin — existence of the track set is the race, not its progress.

## GSAP contract

`document.getAnimations()` does NOT cover GSAP (it drives inline styles off performance.now). The virtual clock pins GSAP implicitly, but converted apps should expose `window.__MOTION_SEEK(ms)` → `gsap.globalTimeline.pause(); gsap.globalTimeline.time(ms/1000)` plus re-render of any canvas-driven tweens — belt and braces, and required when canvases paint outside tweens.

## Self-check

Capture every keyframe TWICE per run through the full reload protocol; pixelmatch the pair against each other (`nondet_worst_pct`). Zero proves replay determinism; nonzero names the guilty keyframe in its own column instead of masquerading as an app regression inside the reference diff.

## Pitfalls learned

- fps measured via rAF callbacks-per-second is compositor-bound under headless software rendering (--disable-gpu): single windows swing 66-92 on identical code. Use median-of-3 × 2s windows, and don't expect renderer-side optimizations to move it while the render loop self-throttles below the cadence.
- JS physics that integrates only while IntersectionObserver-visible samples a visibility-timing lottery; make the simulation catch up to the frame clock in capped substeps so pose = f(elapsed time).
- vite preview binds ::1 by default — pass `--host 127.0.0.1` when scripting curl checks.
- WebGL source-texture rationing (one per frame) means early frames show fallback tints; wait past generation before capturing.
- Concurrent editors saving during a run produce torn module reads ("Illegal return statement") and can silently revert uncommitted harness fixes — md5-check file stability before benching, and commit harness changes immediately after verification.
