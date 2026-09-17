---
name: web-app-cdp-clone-verify
description: "Procedure for inspecting target sites via Chrome CDP, extracting styles/assets, building TanStack Start + Tailwind CSS v4 clones, and running multi-keyframe scroll verification."
---

# Web App CDP Clone & Verification Procedure

Use this procedure when tasked with cloning a web application or landing page with exact layout, styling, and scroll animations.

## Workflow

### 1. Launch Chrome CDP & Inspect Target Site
- Connect to Chrome remote debugging port 9222.
- Execute CDP calls via WebSocket to extract:
  - Document tree & computed styles (`Runtime.evaluate`)
  - All loaded CSS rules (`document.styleSheets`)
  - Images, SVGs, and media assets
  - Layout metrics (`innerWidth`, `visualViewport`, DPR)

### 2. Scaffold Stack & Architecture
- Framework: **TanStack Start** (`@tanstack/react-start` + `@tanstack/react-router`)
- Styling: **Tailwind CSS v4** (`@import "tailwindcss";`)
- Document Shell: Wire `links: [{ rel: 'stylesheet', href: appCss }]`, `<HeadContent />`, and `<Scripts />` in `src/routes/__root.tsx`
- 3D Graphics: Three.js (`three`) WebGL canvas with responsive viewport metrics

### 3. Implement Key Components & Design Tokens
- Map CSS custom variables (`:root` / `html.light`) for surface, accent, and typography.
- Implement glow animations (`.shine`) with `offset-path: border-box` and `@keyframes trail`.
- Implement responsive layout rules for desktop vs mobile viewports.

### 4. Multi-Keyframe Scroll & Viewport Verification
- Set explicit emulation metrics on CDP tabs (`Emulation.setDeviceMetricsOverride`).
- Trigger `Page.reload` after viewport metric overrides to ensure accurate layout calculation.
- Capture screenshots across 5 scroll keyframe offsets (0px, 250px, 500px, 750px, 1000px) for both clone and reference to confirm visual convergence.
