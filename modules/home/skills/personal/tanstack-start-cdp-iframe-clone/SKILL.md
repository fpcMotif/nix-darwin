---
name: tanstack-start-cdp-iframe-clone
description: "Inspect iframe-embedded web apps via Chrome CDP port 9222, extract section HTMLs, videos, stylesheets, and scaffold a TanStack Start + Tailwind v4 clone"
---

# TanStack Start CDP Iframe Web Clone Workflow

Procedure for inspecting iframe-embedded SPAs (e.g. Google Labs / AppCompanion) via Chrome CDP port 9222, extracting section HTMLs, media assets, stylesheets, keyframes, and building a matching TanStack Start + Tailwind CSS v4 clone.

## Procedure

### 1. Launch Reference Site & Connect to CDP
- Launch Chrome with remote debugging:
  `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --remote-debugging-port=9222 --headless=new "https://target-site.com"`
- List targets via `http://127.0.0.1:9222/json/list`. If the app uses an iframe wrapper, target the iframe WebSocket endpoint (`webSocketDebuggerUrl`).

### 2. Extract DOM Structure, Section HTMLs & Assets
- Connect via WebSocket CDP and execute `Runtime.evaluate` to dump individual section HTMLs:
  - Header, Hero, Video player, Templates carousel, Features grid, FAQ accordions, Footer.
- Extract video `.mp4` sources, image URLs, SVG icons, and computed CSS properties.
- Extract keyframe animation rules (`@keyframes`) and stylesheet rules from `document.styleSheets`.

### 3. Scaffold TanStack Start + Tailwind v4 App
- Install TanStack packages: `@tanstack/react-start`, `@tanstack/react-router`, `@tanstack/router-plugin`.
- Install Tailwind CSS v4: `tailwindcss`, `@tailwindcss/vite`.
- Configure `vite.config.ts` with `tanstackStart()`, `@tailwindcss/vite`, and `@vitejs/plugin-react`.
- Configure `src/router.tsx`, `src/routes/__root.tsx`, and `src/routes/index.tsx`.

### 4. Implement Pixel-Exact Components
- Replicate section HTML classes and responsive breakpoints (`md:text-[45px]`, `max-w-[1600px]`, `aspect-ratio: 1144 / 644`).
- Match video background elements, horizontal scroll carousels (`template-browser-scroll`, `scroll-snap-type: x mandatory`), and navigation controls.
- Replicate recursive sub-page routes (e.g., `/projects/$projectId`, `/privacy`, `/terms`).

### 5. Multi-Keyframe CDP Verification
- Build and serve the app locally (`bun run build`, `bun run dev`).
- Connect to Chrome CDP WebSocket and navigate a tab to `http://localhost:5173/`.
- Evaluate `document.title`, `document.querySelector(...)`, section rects, video sources, and card counts to verify 1:1 parity with the reference site.
