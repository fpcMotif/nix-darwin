---
name: tanstack-start-matterjs-physics-clone
description: Procedure for building TanStack Start + Tailwind CSS v4 + Matter.js 2D physics + GSAP web clones with CDP verification.
---

# TanStack Start + Tailwind CSS v4 + Matter.js Physics Web Clone

Procedure for scaffolding and building pixel-accurate web app clones using TanStack Start, Tailwind CSS v4 OKLCH color space, Matter.js 2D physics engines, and GSAP animations.

## Workflow

1. **DOM & Asset Inspection**:
   - Use `bunx agent-browser` or CDP port 9222 to extract live site DOM tree, CSS computed styles, SVG paths, and media URLs (`.webm`, `.mp4`, `.webp`).
   - Extract exact typography (Google Sans), responsive breakpoints (`352x222` mobile / `722x455` medium / `1888x700` desktop / `8500px` carousel circle).

2. **Project Setup**:
   - Initialize TanStack Start project with `@tanstack/react-start/plugin/vite`, `@vitejs/plugin-react`, and `@tailwindcss/vite`.
   - Configure OKLCH color palette variables (`oklch(...)`) in `app/styles/app.css`.

3. **Physics & Animation Engineering**:
   - Use `matter-js` for interactive 2D rigid body physics (falling elements, pointer drag, collision boundaries, restitution, friction).
   - Use `gsap` for smooth slide transitions, trigonometric carousel wheel rotation, and scroll progress tracking.

4. **SSR & Build Verification**:
   - Run `bunx tsc --noEmit` to verify type safety.
   - Run `bunx vite build` to verify SSR server (`dist/server/server.js`) and client (`dist/client/`) bundle generation.
   - Use `bunx agent-browser` with CDP for visual diff inspection across desktop and mobile viewports.
