---
name: tanstack-start-cdp-clone-procedure
description: Procedure for scaffolding TanStack Start + Tailwind CSS v4 web clones with GSAP interactive components and CDP visual verification
---

# TanStack Start + Tailwind v4 Web Clone Procedure

## Overview
This skill provides a procedure for creating pixel-accurate web app clones (such as Google Labs) using TanStack Start, Tailwind CSS v4, and GSAP/Three.js interactive components.

## Workflow

### 1. Structure & Data Extraction via CDP
- Use `bunx agent-browser` or CDP to open the reference site: `bunx agent-browser open <URL>`.
- Extract exact computed styles, DOM layout hierarchy, media URLs (WebM videos, WebP poster images), typography metrics, and color variables via `bunx agent-browser eval`.
- Check responsive behavior at desktop (1440x900) and mobile (390x844) viewports.

### 2. Tech Stack Setup
- **Framework**: TanStack Start with Vite (`tanstackStart` plugin from `@tanstack/react-start/plugin/vite`, `@vitejs/plugin-react`).
- **Styling**: Tailwind CSS v4 (`@tailwindcss/vite`, `tailwindcss`).
- **Animation**: GSAP (`gsap`) for timeline transitions, trigonometric wheel rotations, crossfades.
- **UI Primitives**: Radix UI / base-ui (`@radix-ui/react-dialog`, `clsx`, `tailwind-merge`).

### 3. Architecture & Section Order
- Header: Absolute position overlay on top of dark hero section.
- Featured Hero: `height: 100dvh; min-height: 620px` with stacked video slides and GSAP crossfades.
- Experiment Wheel: Dark section (`#1A1A1A`) with responsive rotating circle (`3300px` / `8500px` / `8000px`), trigonometric card placement along top arc, and centered arrow navigation row below.
- Additional Sections: About pillars, Graduation section ("Life beyond the Lab"), Pre-footer email signup, Footer.

### 4. Verification
- Verify build emits both client (`dist/client/`) and server (`dist/server/`) outputs: `bunx vite build`.
- Test SSR HTML rendering via `curl -s http://localhost:3000/`.
- Verify CDP visual layout and accessibility tree across viewports using `bunx agent-browser`.
