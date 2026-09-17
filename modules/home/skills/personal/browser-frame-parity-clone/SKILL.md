---
name: browser-frame-parity-clone
description: "Verify a website clone against its live original frame-by-frame using the browser tool: matched DPR2 viewports, fixed scroll-position sweep on both tabs, side-by-side screenshot comparison, exact asset URL extraction from live DOM, and clone corrections. Use when a clone \"doesn't quite match\" the original and pixel-level differences need to be found and fixed."
---

# Frame-by-frame live-vs-clone parity via browser tool

Workflow for finding and fixing visual drift between a clone and the live site it replicates. Validated end-to-end replicating cosmoschem.com/en.

## Protocol

1. **Capture live reference**: `browser open` the live URL in a `"live"` tab with `viewport: { width: 1440, height: 900, scale: 2 }` (DPR 2). Wait ~1.5s after load.
2. **Scroll sweep**: fixed positions (e.g. every 400px to page height). Per frame: `tab.evaluate((p) => window.scrollTo(0, p), pos)` → wait 350–500ms → `tab.screenshot()`. Return all frames in one `run` call.
3. **Capture clone identically**: same tab pattern (`"cosmos"` tab), same viewport, same positions. Identical waits.
4. **Compare side-by-side**: attach both frame sets; per scroll position judge section structure, copy, imagery, and interactive state.
5. **Extract ground truth from live DOM** when a section mismatches:
   - `document.querySelectorAll` on the live section for `img[src]`, `getComputedStyle(el).backgroundImage`, class names.
   - `document.elementFromPoint(x, y)` to identify what renders at a visual feature — critical when imagery is baked into a poster/video frame rather than being a DOM element (a "COSMOS" wordmark was part of the video poster `3.webp`, not text or an img).
   - Download exact asset URLs into the clone's `public/` mirroring the source path.
6. **Fix the clone**, re-run the sweep, re-compare.

## Gotchas learned

- **Baked-in visuals**: hero/wordmark imagery often lives inside `<video poster>` or background images, not DOM. Probe with `elementFromPoint` before assuming a DOM node exists.
- **lucide-react brand icons**: `Facebook`/`Linkedin` may not exist in the installed version → write inline SVG components (`src/components/icons.tsx`) instead of fighting the package.
- **StyleX + `background-clip: text`**: unreliable through `stylex.create`; if the effect must be textured text, prefer the source site's actual mechanism (often a plain image) over CSS clipping.
- **Dead framework scaffold**: leftover entry files (`client.tsx`, `ssr.tsx`, `app.config.ts`) from an abandoned stack cause tsc noise — delete them before final verification.
- **Verify with real gates**: `tsc --noEmit` (0 errors) + production build must pass before declaring done; visual claims need the frame sweep as evidence.
- **Edit tool on generated/complex files**: re-read the touched region after any multi-line edit; a wrong range endpoint silently clobbers adjacent JSX/styles (happened twice in one session).

## Deliverable shape

A comparison table: scroll position | live description | clone description | match status, plus a list of corrections made (asset swaps, structural merges, dead-code removal) and final `tsc`/build proof.
