---
name: tanstack-start-cdp-clone-verify
description: Procedure for scaffolding TanStack Start + Tailwind CSS v4 web clones and running aligned CDP port 9222 visual verification
---

# TanStack Start + Tailwind v4 Web Cloning & CDP Verification Workflow

Procedure for building production-grade TanStack Start web clones and verifying 1:1 visual and animation parity using Chrome DevTools Protocol (CDP) port 9222.

## 1. Project Scaffolding
- Use `bun create vite <project-name> --template react-ts`
- Install TanStack dependencies: `@tanstack/react-start`, `@tanstack/react-router`, `@tanstack/router-plugin`
- Install Tailwind CSS v4: `tailwindcss`, `@tailwindcss/vite`
- Configure `vite.config.ts` with `tanstackStart()`, `@tailwindcss/vite`, and `@vitejs/plugin-react`
- Export `getRouter` in `src/router.tsx` and configure `src/routes/__root.tsx` with TanStack Start document shell (`<HeadContent />`, `links: [{ rel: 'stylesheet', href: appCss }]`, `<Scripts />`)

## 2. Source Asset & Token Extraction via CDP
- Launch Chrome with remote debugging: `Google Chrome --remote-debugging-port=9222`
- Inspect reference site HTML, CSS rules, fonts (`Google Sans`), and media assets (`.svg`, `.png`, `.jpg`)
- Download static media assets into `public/assets/`
- Extract exact computed CSS rules, colors (`--surface`, `--on-surface`, `--accent`), font sizes, and layout bounding rects

## 3. WebGL / Canvas & Animation Integration
- For 3D canvas sections, match target DOM contract: `section.sticky-hero-cube-section` (`position: sticky; top: 0; height: 1100px; width: 100%`) with direct `1152x640` canvas child (`width="2304" height="1280"`)
- Derive scroll progress from section document-space offsets: `(window.scrollY - sectionTop) / (sectionHeight - window.innerHeight)`
- Use Three.js (`three`) to render responsive 3D scenes or canvas animations

## 4. Multi-Keyframe CDP Visual Verification
- Open both clone (`http://127.0.0.1:5173/`) and reference (`https://target-site/`) in Chrome on port 9222
- Override viewports to identical desktop (`1440x900`, scale 2) and mobile (`390x844`, scale 3) dimensions
- Trigger `Page.reload({ ignoreCache: true })` on both tabs
- Scroll to keyframe offsets (`y=0`, `250`, `500`, `750`, `1000`) and capture PNG screenshots (`Page.captureScreenshot`)
- Use `pngjs` to decode raw RGBA pixel buffers and calculate per-channel MAE (Mean Absolute Error) and RGBA similarity metrics
