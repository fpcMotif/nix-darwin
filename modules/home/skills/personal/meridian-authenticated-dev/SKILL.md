---
name: meridian-authenticated-dev
description: "Start and debug MERIDIAN Vue/Express development with matching auth modes, Vite ports, and CDP verification"
---

# Meridian Authenticated Dev & CDP Verification Workflow

## 1. Starting Dev Services in Matching Mode
The project has dual auth modes (demo vs authenticated). Starting mismatched modes causes 401s or immediate redirects.

- **Demo mode (no login, synthetic admin)**:
  `cd /Users/martinfan/devv/vue3 && bun run dev`
  - Frontend: `http://localhost:5173/command`
  - Backend: `http://localhost:3000` (AUTH_ENABLED=false)

- **Authenticated mode (RBAC, JWT, login required)**:
  `cd /Users/martinfan/devv/vue3 && bun run dev:auth`
  - Frontend: `http://localhost:5173/login` (VITE_AUTH_ENABLED=true)
  - Backend: `http://localhost:3000` (AUTH_ENABLED=true, AUTH_SECRET=dev-only-secret)
  - Credentials: `admin / admin`, `j.reyes / operator`, `l.okafor / operator`

- **Takeover 3D Demo**:
  `http://localhost:5173/takeover-demo.html`

## 2. Port & Concurrency Gotchas
- Root dev scripts use `bunx concurrently --kill-others-on-fail` to ensure cross-shell binary resolution.
- Vite is configured with `strictPort: true` on `5173` to prevent silent port drift to 5174/5175.
- Always check if ports 3000 or 5173 are occupied before spawning dev stacks:
  `lsof -nP -iTCP:3000 -iTCP:5173 -sTCP:LISTEN`
- Kill any stale orphan processes before starting:
  `kill -KILL <PID>`

## 3. CDP Verification Workflow
- Connect via `xd://browser` to `http://localhost:5173/login` or `http://localhost:5173/takeover-demo.html`.
- For 3D demos, inspect runtime errors using dynamic module imports in `tab.evaluate`:
  `await import('/src/demo/takeoverDemo.js?test=' + Date.now())`
- Verify camera, canvas width/height, scene objects, and HUD DOM synchronizations.
- Capture screenshots via `tab.screenshot({ silent: true })` to verify visuals across flight phases.
