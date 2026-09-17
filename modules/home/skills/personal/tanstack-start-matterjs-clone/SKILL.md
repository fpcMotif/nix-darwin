---
name: tanstack-start-matterjs-clone
description: "Procedure for cloning web applications with TanStack Start, Tailwind v4 OKLCH colors, Matter.js 2D physics engines, and GSAP animations."
---

# TanStack Start + Tailwind v4 + Matter.js / GSAP Web Cloning

Procedure for building pixel-accurate TanStack Start clones with Tailwind CSS v4 OKLCH colors, Matter.js 2D physics engines, and GSAP animations.

## Workflow Steps

1. **Extract Live DOM, Styles, & Media via CDP**
   - Extract exact text copy, media URLs (videos/webp), SVG paths, computed styles, and element bounds using `bunx agent-browser eval`.
   - Inspect custom web components (`app-*`), `@keyframes`, and layout hierarchy.

2. **TanStack Start & Tailwind CSS v4 Setup**
   - Configure `vite.config.ts` with `tanstackStart({ srcDirectory: 'app' })`, `@vitejs/plugin-react`, and `@tailwindcss/vite`.
   - Define OKLCH color variables in `app/styles/app.css` (`oklch(...)`) for wide gamut color palettes.
   - Export `getRouter` and `createRouter` in `app/router.tsx`.

3. **Matter.js 2D Rigid Body Physics Engine**
   - Initialize `Matter.Engine`, `Matter.World`, `Matter.Bodies`, `Matter.MouseConstraint`, and `Matter.Runner`.
   - Support responsive stage sizing, window resize bounds update, and 1.1s staggered entrance drop.
   - Sync Matter.js body coordinates to DOM SVG elements via `transform: translate(x, y) rotate(angle)`.

4. **Verification & Audit**
   - Run `bunx tsc --noEmit` and `bunx vite build`.
   - Inspect SSR rendered HTML via `curl` and client runtime via `agent-browser` CDP.
