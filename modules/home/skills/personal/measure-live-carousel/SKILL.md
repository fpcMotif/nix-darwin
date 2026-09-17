---
name: measure-live-carousel
description: "Measure a live marketing-site hero carousel via CDP: probe canvas/video/WAAPI engines, extract slide data from DOM, frame-by-frame the transition, rebuild deterministically"
---

# Measure a live site's featured-hero carousel (frame-by-frame + data extraction)

Procedure used to decode labs.google's featured hero for a GSAP rebuild. Works for any marketing-site carousel.

## 1. Probe the effect engine first (don't assume shaders)
Open the site in a CDP-driven browser and evaluate one script:
- `document.querySelectorAll('canvas')` → any WebGL/WebGL2? (shaders) 
- `document.querySelectorAll('video')` → `{currentSrc, videoWidth, muted, loop, autoplay}` (footage-driven)
- `document.getAnimations()` → types + names (CSS keyframes vs transitions vs WAAPI)

labs.google result (2026-08): zero canvases; per-experiment `.webm` hero loops under `/assets/videos/featured-hero/*.webm`; motion = CSS `gl-float-x/y/r` SVG shapes + a `width` CSSTransition progress fill. The "shader look" lives inside the AI-generated footage, not page code.

## 2. Extract slide data from DOM, not screenshots
Walk up from a known child class (e.g. `[class*=progress-fill]`) to find the carousel root, then:
- titles: headings inside each slide container
- taglines: sibling `<p>` of each title  
- media srcs: `<video>`/`<img>` `currentSrc`
- CTAs: anchors with their real hrefs
- treatment: `getComputedStyle(video)` — object-fit/filter/transform (labs.google: plain cover, no filter; blur lives in the footage)

## 3. Frame-by-frame the transition
Click the next-arrow via CDP, then screenshot at ~110ms intervals ×8. Read frames as a sequence to classify the choreography. labs.google: text crossfades IN PLACE (old/new overlap), dark rounded-hexagon blob scales up over the handoff with incoming title readable on it, background footage crossfades, progress restarts.

## 4. Rebuild rules that kept replay deterministic
- All gesture/settle timing keyed off an injected virtual rAF clock (fixed 16.67ms steps), never wall-clock sleeps — scheduler jitter flows straight into velocity estimation / snap targets.
- Auto-advance driven BY the progress tween's onComplete (progress = timer).
- If the app freezes mid-pose for benchmarks, expose `window.__MOTION_SEEK(ms)` pausing gsap.globalTimeline.
- CSS `visibility:hidden` on a parent hides children even when the child sets `visibility:visible` — control overlay reveal via the element GSAP animates, not an ancestor class.
