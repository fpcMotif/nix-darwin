---
name: cdp-tanstack-web-clone
description: "Procedure for inspecting target sites via Chrome CDP port 9222, building TanStack Start + Tailwind CSS v4 clones, and verifying layout metrics and screenshots."
---

# CDP TanStack Web Clone & Verification

Procedure for inspecting target web applications via Chrome CDP port 9222, building pixel-accurate TanStack Start + Tailwind CSS v4 clones, and verifying layout metrics and screenshots.

## Workflow

### 1. Target Site Inspection via CDP (Port 9222)
- Start Chrome with `--remote-debugging-port=9222`.
- Query `http://127.0.0.1:9222/json/list` to find target tab's `webSocketDebuggerUrl`.
- Connect via WebSocket CDP, enable `Page`, `DOM`, `Runtime` domains.
- Extract outer HTML, computed CSS rules, custom variables, keyframe animations (`trail`, `offset-path`), and media assets.

### 2. Scaffold TanStack Start Project
- Scaffold React + Vite project with Bun: `bun create vite <project-name> --template react-ts`.
- Add dependencies: `bun add @tanstack/react-start @tanstack/react-router tailwindcss @tailwindcss/vite`.
- Wire `tanstackStart()` plugin in `vite.config.ts`.
- Export `getRouter()` in `src/router.tsx`.
- Wire TanStack Start document shell in `src/routes/__root.tsx`:
  - `links: [{ rel: 'stylesheet', href: appCss }]`
  - `<HeadContent />` inside `<head>`
  - `<Scripts />` before `</body>`

### 3. Metric & Screenshot Verification
- Apply `Emulation.setDeviceMetricsOverride`:
  - Desktop: `{ width: 1440, height: 900, deviceScaleFactor: 2, mobile: false }`
  - Mobile: `{ width: 390, height: 844, deviceScaleFactor: 3, mobile: true }`
- Trigger `Page.reload` on both clone and target reference tabs to force viewport recalibration.
- Evaluate layout metrics (`window.innerWidth`, `visualViewport.width`, `devicePixelRatio`, `clientWidth`) to ensure 100% parity.
- Capture side-by-side screenshots via `Page.captureScreenshot`.
