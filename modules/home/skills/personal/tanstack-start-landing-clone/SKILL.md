---
name: tanstack-start-landing-clone
description: "Procedure for 1:1 pixel-accurate landing page cloning using TanStack Start, Tailwind v4, Base UI, oxlint type-aware rules, oxfmt, asset extraction, and strict per-section fixed-canvas decoded RGBA pixel CDP verification."
---

# 1:1 Pixel-Accurate Landing Page Cloning Procedure (TanStack Start + Tailwind v4 + Base UI + Fixed-Canvas CDP Verification)

Use this procedure when tasked with cloning landing pages pixel-by-pixel with high aesthetic fidelity, zero AI slop, strict type-aware linting, and automated Chrome CDP RGBA section bounding box verification.

## 1. CDP Data & Asset Extraction Workflow
1. Launch target site in browser/CDP or inspect via `bunx agent-browser`.
2. Extract exact inline SVGs, CSS variables, typography (`@font-face` / Google Fonts), and background effects (`.grain::before` SVG fractalNoise filter).
3. Download all media assets (`.mp4` video demos, `.webp` ASCII update cards, favicons) directly into `./public/`.
4. Extract live `<header>`, `<nav>`, handwritten annotations (`(not sped up, promise)`), and text content into `/src/constants/landing-data.ts` to guarantee zero magic numbers or hardcoded inline strings.

## 2. Live Video Player Note & Proof Row Placement
- **Hero CTA**: Download button (`Download for Mac`) with handwriting subtext `(free dictation. no subscription.)` in `Gloria Hallelujah` font (`color: var(--color-text-muted)`).
- **Video Note**: Wrap video container in `relative w-full`. Place note span absolutely at `-bottom-8 right-2 lg:-bottom-10 lg:-right-6 whitespace-nowrap` with `font-family: "Gloria Hallelujah", cursive`, `color: var(--color-accent)`, and `transform: rotate(-4deg)` (untouched CSS transforms).
- **Canvas Audio Waveform**: Render animated `<canvas>` waveform pill inside Pillar 1 (`Press and speak`).
- **Pillar Icons & Proof Row**: Pillar 2 (3 app icons), Pillar 3 (Lock outline icon), Proof Row: `<p className="mt-12 text-center text-[14px]">Loved by <a href="/dictation-for-developers">developers</a>, sore wrists, clinicians, and frequent flyers.</p>`

## 3. Technical Stack Setup
```bash
bunx @tanstack/cli create --non-interactive --package-manager bun --framework React . -f
bun add @base-ui-components/react clsx lucide-react oxlint oxlint-tsgolint oxfmt pngjs @types/pngjs
```

## 4. Package.json Validation Scripts
Add the following scripts to `package.json`:
```json
{
  "scripts": {
    "lint": "oxlint --type-aware src",
    "typecheck": "tsc --noEmit",
    "format": "oxfmt src",
    "verify": "bun run scripts/verify-clone.js"
  }
}
```

## 5. Strict Type-Aware Linting Rules
Create `.oxlintrc.json` with strict rules:
- Ban `Record<string, unknown>` and `Record<string, any>`.
- Enforce `react/rules-of-hooks` and `react/exhaustive-deps`.
- Enforce clean, idiomatic React 19 + TanStack Start code with zero AI slop.

```json
{
  "$schema": "./node_modules/oxlint/configuration_schema.json",
  "plugins": ["react", "typescript", "jsx-a11y", "unicorn"],
  "rules": {
    "react/rules-of-hooks": "error",
    "react/exhaustive-deps": "error",
    "typescript/no-restricted-types": [
      "error",
      {
        "types": {
          "Record<string, unknown>": {
            "message": "Do not use Record<string, unknown>. Define explicit interfaces instead."
          }
        }
      }
    ]
  }
}
```

## 6. Fixed-Canvas Bounding Box CDP Verification Script
Write `scripts/verify-clone.js` using persistent WebSockets on CDP port 9222:
- Target explicit free port (e.g. `3333`) to prevent port collision.
- Preserve all CSS transforms, rotations (`rotate(-4deg)`), and scroll animations untouched.
- Await `load` event + `document.fonts.ready` + title/DOM text assertions.
- Evaluate section bounding box coordinates (`getBoundingClientRect()`) for all live sections.
- Scroll each element into view, wait 800ms for natural reveal transitions, and check width delta (<= 5%).
- Capture exact `{ x, y, width, height }` bounding box clips on fixed canvas `1440x1000` for both original and clone.
- Decode PNG images into RGBA pixel buffers using `PNG.sync.read` with color tolerance (±20 per RGB channel).
- Enforce pass/fail thresholds for EVERY section individually (≥ 70% per section) and throw an Error if any section fails.
- Save side-by-side PNG section clips in `./verification/elements/`.
