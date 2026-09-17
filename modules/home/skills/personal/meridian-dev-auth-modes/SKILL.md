---
name: meridian-dev-auth-modes
description: "Run and troubleshoot MERIDIAN Vue/Express development in demo or authenticated mode, including bunx concurrently, strictPort checks, and takeover demo."
---

# MERIDIAN Dev & Auth Modes Troubleshooting

## Startup Workflows

### 1. Authenticated Mode (Default for RBAC / manual takeover / audit testing)
Root command:
```bash
cd /Users/martinfan/devv/vue3
bun run dev:auth
```
This runs:
- Server on `http://localhost:3000` with `AUTH_ENABLED=true`, `AUTH_SECRET=dev-only-secret`, `NODE_ENV=development`
- Frontend on `http://localhost:5173` with `VITE_AUTH_ENABLED=true` via `bunx concurrently`

Login credentials:
- Admin: `admin` / `admin`
- Operators: `j.reyes` / `operator`, `l.okafor` / `operator`

### 2. Demo Mode (Zero-auth local testing)
Root command:
```bash
cd /Users/martinfan/devv/vue3
bun run dev
```

## Common Gotchas & Fixes

1. **`WebSocketServer is not defined`**:
   `server/src/telemetry.js` requires `import { WebSocketServer } from 'ws';`.

2. **`concurrently: command not found (exit code 127)`**:
   Subshells spawned by Bun may lack local `./node_modules/.bin` in PATH. Root scripts must use `bunx concurrently --kill-others-on-fail ...`.

3. **`Port 5173 is already in use`**:
   `vite.config.js` sets `strictPort: true` so port conflicts fail fast rather than silently moving to 5174/5175. Clear listeners with:
   ```bash
   lsof -nP -iTCP:3000 -iTCP:5173 -sTCP:LISTEN
   kill -9 <PID>
   ```

4. **3D Takeover Demo**:
   Located at `http://localhost:5173/takeover-demo.html`. Uses Three.js with realistic 21-phase UAV flight dynamics, takeoff spool-up, RTH corridor, PFD artificial horizon, and flare landing.
