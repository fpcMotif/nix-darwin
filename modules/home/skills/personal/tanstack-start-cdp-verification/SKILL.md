---
name: tanstack-start-cdp-verification
description: Multi-keyframe scroll audit and CDP verification procedure for TanStack Start + Tailwind v4 web clones.
---

# TanStack Start CDP Verification

Procedure for building, running, and auditing TanStack Start + Tailwind CSS v4 web clones against reference sites using Chrome CDP (port 9222).

## Procedure

1. **Scaffold & Build**:
   - Ensure `@tanstack/react-start` plugin `tanstackStart()` is wired in `vite.config.ts`.
   - Export `getRouter` in `src/router.tsx`.
   - Include root document shell in `src/routes/__root.tsx` (`HeadContent`, stylesheet link, `Scripts`).
   - Run `bun run build` to compile client (`dist/client/`) and SSR server (`dist/server/server.js`).

2. **Launch Preview & CDP**:
   - Start preview server via `hub` or `bun run preview --host 0.0.0.0 --port 5173`.
   - Launch Google Chrome with `--remote-debugging-port=9222`.

3. **Multi-Keyframe Scroll Audit**:
   - Connect via WebSocket CDP to both clone (`http://127.0.0.1:5173/`) and target reference tabs.
   - Set viewport overrides (e.g. `1440x900`, `deviceScaleFactor: 2` desktop / `390x844`, `deviceScaleFactor: 3` mobile).
   - Trigger `Page.reload` after emulation override to re-evaluate viewport layout and media queries.
   - Scroll through offsets (`0px`, `250px`, `500px`, `750px`, `1000px`) and capture synchronized screenshots for side-by-side verification.
