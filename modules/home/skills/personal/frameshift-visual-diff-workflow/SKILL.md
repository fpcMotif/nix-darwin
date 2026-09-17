---
name: frameshift-visual-diff-workflow
description: Automated visual diff sweep and report generation comparing a live website against a local clone using fixed viewport checkpoints and pixelmatch.
---

# Frameshift Visual Diff Workflow

Procedure for setting up automated visual diff sweeps between a live reference site and a local clone using fixed-viewport scroll checkpoints, pixelmatch, and Frameshift report generation.

## 1. Core Dependencies
```bash
bun add pixelmatch pngjs
bun add -D @types/pixelmatch @types/pngjs
```

## 2. Fixed Viewport Scroll Sweep (`scripts/frameshift-sweep.ts`)
Instead of `fullPage: true` (which glitches on sticky headers and scroll-triggered animations), capture fixed-viewport slices (1440x900) at distinct scroll coordinates:

```ts
const checkpoints = [
  { name: "hero__desktop.png", path: "/", scrollY: 0 },
  { name: "features__desktop.png", path: "/", scrollY: 800 },
  { name: "slider__desktop.png", path: "/", scrollY: 1600 },
  { name: "pricing__desktop.png", path: "/", scrollY: 2400 },
  { name: "catalog__desktop.png", path: "/catalog" },
  { name: "login__desktop.png", path: "/login" },
];
```

Capture `baseline/` from target URL and `candidate/` from `http://localhost:3000`.

## 3. Pixelmatch Comparison Engine (`scripts/frameshift-compare.ts`)
Compare baseline and candidate PNGs using `pixelmatch`:
- Output diff images to `test-output/report/images/diff/` with custom highlight color (e.g. `[253, 141, 104]`).
- Generate `report.json` with status (`changed`, `added`, `removed`, `unchanged`), diff percentage, and bounding dimensions.
- Emit interactive `index.html` report viewer with Highlights, Drag Slider, Side-by-side, and Fade modes.
