---
name: tanstack-start-codewiki-clone
description: Procedure for scaffolding TanStack Start + Tailwind CSS v4 + Three.js web app clones and verifying them via Chrome CDP port 9222
---

# TanStack Start + Tailwind v4 + Three.js Clone Workflow

## Scaffolding & Dependencies
1. Scaffold Vite React-TS project with `bun create vite <project-name> --template react-ts`.
2. Install TanStack Start and Router dependencies:
   `bun add @tanstack/react-start @tanstack/react-router lucide-react three clsx tailwind-merge`
   `bun add -D @tanstack/router-plugin tailwindcss @tailwindcss/vite @types/three`

## Configuration
1. Update `vite.config.ts`:
   - Import `tanstackStart` from `@tanstack/react-start/plugin/vite`
   - Import `tailwindcss` from `@tailwindcss/vite`
   - Configure `plugins: [tanstackStart(), react(), tailwindcss()]`

2. Configure TanStack Router:
   - `src/router.tsx`: Export `createRouter()` and `getRouter` factory for SSR server.
   - `src/routes/__root.tsx`: Provide document shell (`<html lang="en">`, `<head>`, `<HeadContent />`, `links: [{ rel: 'stylesheet', href: appCss }]`, `<body>`, `<Outlet />`, `<Scripts />`).
   - `src/routes/index.tsx`: Main route component.

3. Styling & Fonts:
   - Import Google Sans fonts in `src/index.css`.
   - Add `@import "tailwindcss";` and custom CSS theme variables.

## Verification via CDP Port 9222
1. Launch Chrome with remote debugging:
   `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-cdp-verify "http://127.0.0.1:5173/" "https://target-site/"`
2. Connect WebSocket to `http://127.0.0.1:9222/json/list` targets.
3. Override viewport metrics (`Emulation.setDeviceMetricsOverride`), trigger `Page.reload({ ignoreCache: true })`, and capture 5-keyframe scroll screenshots.
