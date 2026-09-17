---
name: meridian-dev-run-verify
description: "Run and verify the MERIDIAN Vue3 drone-fleet monorepo: alternate dev ports (5173 is taken by another app), IPv6-only vite binding vs readiness probes, demo/dashboard entry URLs, three.js drone-model userData contract, headless rAF throttling workaround, and the private GitHub remote fpcMotif/meridian"
---

# MERIDIAN (vue3 monorepo) — run, verify, and edit safely

## Launch
- Backend: `hub start meridian-server`: `bun run dev`, cwd `<repo>/server`, ready = TCP :3000.
- Web: `bun run dev -- --port 5174`, cwd `<repo>/web`. NEVER assume :5173 — the user runs an unrelated Vite app ("Northlight Labs") there; this repo's config is `strictPort: 5173` so default startup fails with EADDRINUSE.
- Readiness gotcha: vite binds IPv6 `::1` only. A hub `ready.port` probe on `127.0.0.1:5174` times out even when healthy. Trust the `Local:` log banner instead of the port probe.

## Entry points
- Main dashboard: `http://localhost:5174/` (CommandCenter → `web/src/components/MapCesium.vue`; drones need the :3000 backend up).
- Three.js takeover demo: `http://localhost:5174/takeover-demo.html` (client-side sim, no backend needed).

## Demo model contract (`web/src/demo/takeoverDemo.js`)
`syncScene()` depends on exactly this shape — never break:
- `drone.userData = { props, discs, status, beacon }`
- `props[]`: Groups spinning on `.rotation.y`, each needs `userData.spin` (+1/-1)
- `discs[]`: CircleGeometry blur discs using `propBlurTex`; opacity driven externally; keep `transparent, depthWrite:false, side:DoubleSide`
- `status`: PointLight recolored via `.color.setHex()`; `beacon`: MeshBasicMaterial sphere recolored via `.material.color.setHex()`
- Lowest landing-foot bottom at y = -2.05 exactly (scene adds `baseGear = 2.05`); aircraft nose points -Z

## Headless verification quirk
In hidden headless tabs the demo's rAF throttles to ~0 — clock stalls at T+00:00 unless frames are forced. To show the user the running demo, `open http://localhost:5174/takeover-demo.html` in their default browser instead.

## Repo hygiene
Private GitHub remote already exists: `fpcMotif/meridian` (PRIVATE, verified). `Archive.zip` is gitignored — do not commit it.
