---
name: cdp-web-clone-verification
description: "Procedure for inspecting target sites via CDP port 9222, extracting assets, building TanStack/Tailwind v4 clones, and verifying with aligned screenshots."
---

# CDP Web Clone Verification Workflow

Use this workflow when tasked with creating a 1:1 pixel-accurate clone of a target website using Chrome CDP (port 9222), TanStack Router/Start, Tailwind CSS v4, and Three.js.

## 1. CDP Discovery & Asset Inspection
- Launch Google Chrome with `--remote-debugging-port=9222`.
- Connect via CDP WebSocket (`http://127.0.0.1:9222/json/list`) to evaluate the target site.
- Extract outer HTML, computed CSS styles, keyframes (`@keyframes trail`), fonts, and media URLs (`.svg`, `.png`).
- Save target SVG logos and responsive images locally to `/public/assets/`.

## 2. Project Setup & Architecture
- Scaffold with `bun` using TanStack Router/Start (`@tanstack/react-router`, `@tanstack/react-start`, `@tanstack/router-plugin`).
- Add Tailwind CSS v4 (`@tailwindcss/vite`) and Three.js (`three`) if 3D canvas animations are present.
- Configure `vite.config.ts` with `TanStackRouterVite()` and `tailwindcss()`.

## 3. UI Component Engineering
- Match font sizes, line heights, letter spacings, and computed colors (`var(--on-surface)`, `var(--neutral)`, `var(--surface)`).
- Implement `.shine` border animations using CSS `offset-path: border-box` and `@keyframes trail`.
- Implement responsive breakpoints (`@media (min-width: 1024px)`) for desktop vs mobile components.
- For 3D canvas scenes, set up Three.js scenes with `PerspectiveCamera`, wireframe geometries (`EdgesGeometry`), and scroll-driven rotation choreography.

## 4. Aligned CDP Visual Verification
- Start the app preview server on port 5173 (`bun run preview`).
- Open both the local app (`http://127.0.0.1:5173/`) and reference (`https://target-site/`) in Chrome CDP.
- For BOTH tabs:
  1. Force scroll to top (`window.scrollTo(0, 0)`).
  2. Set viewport explicitly (`1440x900` for desktop, `390x844` for mobile).
  3. Wait 1.5s for layout/fonts to settle.
  4. Capture aligned screenshots for comparison.
