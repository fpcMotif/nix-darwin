---
name: meridian-dev-mode-cdp
description: "Start and troubleshoot MERIDIAN Vue/Express development in demo or authenticated mode, resolve Vite port conflicts, and verify API/UI via CDP."
---

# MERIDIAN Dev Mode & CDP Verification Workflow

## Fast Start

From project root `/Users/martinfan/devv/vue3`:

```bash
# Clean start (ensures ports 3000 & 5173 are free)
lsof -nP -iTCP:3000 -iTCP:5173 -sTCP:LISTEN

# Authenticated Mode (Full RBAC + Fences + Safety)
bun run dev:auth

# Demo Mode (No auth required)
bun run dev
```

## Key Endpoints
- **Takeover 3D Demo:** `http://localhost:5173/takeover-demo.html`
- **Command Deck:** `http://localhost:5173/command` (or `/login` in auth mode)
- **Backend Health:** `http://localhost:3000/api/health`

## Credentials (Auth Mode)
- Admin: `admin` / `admin`
- Operator: `j.reyes` / `operator`
- Operator: `l.okafor` / `operator`

## Common Gotchas & Fixes
1. **Port 5173 Conflict:** If Vite says `Port 5173 is already in use`, terminate old processes:
   ```bash
   kill -KILL $(lsof -t -iTCP:5173) 2>/dev/null || true
   ```
2. **Subshell Concurrency:** Always use `bunx concurrently` in root scripts so non-standard subshells resolve the binary.
3. **Lazy Convex Driver:** `server/src/db/convex.js` uses dynamic `import('convex/browser')` so tests under memory driver run without requiring convex packages.
