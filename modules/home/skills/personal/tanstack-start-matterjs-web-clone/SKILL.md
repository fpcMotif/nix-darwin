---
name: tanstack-start-matterjs-web-clone
description: Procedure for building TanStack Start + Tailwind v4 + Matter.js 2D physics + GSAP web clones with CDP verification
---

# TanStack Start + Tailwind v4 + Matter.js + GSAP Web Clone Workflow

This procedure details how to scaffold, extract assets for, and build pixel-accurate web application clones using TanStack Start, Tailwind CSS v4 OKLCH colors, Matter.js 2D physics engines, GSAP carousels, and CDP port 9222 verification.

## Procedure

### 1. Inspect & Extract Assets via CDP
- Use `agent-browser` or CDP port 9222 to evaluate DOM metrics, styles, SVGs, videos, images, and former product name mappings.
- Extract exact computed styles: `position`, `fontSize`, `fontWeight`, `lineHeight`, `color`, `backgroundColor`, `borderRadius`, `padding`, `gap`.
- Save full media URLs (WebM/MP4 videos, WebP images, SVG path strings).

### 2. Scaffold TanStack Start + Tailwind CSS v4
- Use `@tanstack/react-start/plugin/vite` + `@vitejs/plugin-react` in `vite.config.ts`.
- Export `createRouter` and `getRouter` in `app/router.tsx`.
- Configure OKLCH color space variables (`oklch(...)`) in `app/styles/app.css` for wide gamut, perceptually uniform color blending.

### 3. Matter.js 2D Rigid Body Physics Engine
- Implement interactive falling element/block toy components using `Matter.Engine`, `Matter.World`, `Matter.Bodies`, `Matter.MouseConstraint`, and `Matter.Runner`.
- Use exact polygon/rectangle/circle body collision outlines, responsive stage dimensions, floor/wall static boundaries, 1.1s staggered entrance drop (70ms spacing), and sync Matter.js `body.position`/`body.angle` to DOM `transform: translate(x, y) rotate(rad)`.

### 4. GSAP Full-Bleed & Carousel Wheel Mechanics
- Implement full-width hero video slides with GSAP `power2.inOut` crossfades and centered responsive typography (`50px / 80px / 120px`).
- Implement rotating circle carousel wheel (e.g. `8500px` desktop / `3300px` mobile) placing cards along top arc via trigonometric positioning, with pointer drag snapping and centered controls row below the wheel.

### 5. Typecheck & SSR Verification
- Run `bunx tsc --noEmit` and `bunx vite build` to verify client (`dist/client/`) and server (`dist/server/server.js`) SSR production bundles.
- Verify rendered SSR HTML output via `curl` and audit layout via CDP port 9222.
