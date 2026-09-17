---
name: meridian-demo-visual-verify
description: "Launch and visually verify the MERIDIAN three.js takeover demo and dashboard: alt-port vite startup (IPv6 probe quirk), rAF-throttled headless tab workaround via __demo.seek(), intro-camera wait, orbit close-up recipe, and the syncScene drone-model contracts."
---

# MERIDIAN takeover demo — visual verification recipe

How to launch and visually verify `web/src/demo/takeoverDemo.js` (three.js mission sandbox) and the main dashboard in `/Users/martinfan/devv/vue3`.

## Environment quirks (learned the hard way)
- Port **5173 is occupied** by an unrelated project ("Northlight Labs") on this machine. This repo's vite has `strictPort: 5173` in `web/vite.config.js`, so always start it on an override port:
  ```bash
  cd web && bun run dev -- --port 5174
  ```
- Vite binds **IPv6 `[::1]` only**, so TCP readiness probes against `127.0.0.1:5174` time out even when the server is up. Trust the `Local:` log line instead of a port probe.
- Backend (needed only for the dashboard map markers, not the demo): `cd server && bun run dev` → port 3000; vite proxies `/api` and `/ws`.
- To open the page for the USER, use `open "http://localhost:5174/takeover-demo.html"` (macOS default browser), not the headless tool browser.

## Headless verification pitfalls
1. **rAF throttling**: a hidden headless tab throttles requestAnimationFrame, so the demo's playback stalls near T+00:00 between tool calls. Do NOT wait for wall-clock playback.
2. Use the deterministic seek hook baked into the demo:
   ```js
   window.__demo.seek(52)   // jump to mission time t seconds (clamped to DURATION)
   ```
   It runs simulateTo + syncHud + syncScene + render synchronously — works under throttling. `window.__demo` also exposes `{ camera, controls, drone }`.
3. **Intro camera hijack**: for the first 3.2 s after load (`INTRO_SEC`) the frame loop lerps the camera back to its intro path every tick, overriding any manual camera placement. Wait ≥4 s after load before positioning the camera, or your close-up screenshots show the whole map from above.
4. Close-up recipe:
   ```js
   // switch out of chase cam so the frame loop stops moving the camera
   [...document.querySelectorAll('.cam')].find(b => /orbit/i.test(b.textContent)).click();
   const d = window.__demo, p = d.drone.position;
   d.camera.position.set(p.x + 12, p.y + 4.5, p.z - 17);
   d.controls.target.copy(p); d.controls.update();
   ```
   Drone scale: ~11 units across motor pods; ~14–19 units camera distance frames it well.

## Model realism contract (for edits)
The drone model block in `takeoverDemo.js` feeds `syncScene()` via strict contracts — never break these when re-skinning:
- `drone.userData = { props, discs, status, beacon }`; props = Groups with `userData.spin` ±1 rotating on `.rotation.y`; discs = propBlurTex CircleGeometry meshes (opacity driven externally); status = PointLight, beacon = Mesh (both recolored externally via `.color.setHex()`).
- Nose faces **−Z**; lowest foot bottoms at exactly **y = −2.05** (scene adds baseGear 2.05); keep `rotation.order='YXZ'`, `landLight`, `scene.add(drone)`.

## Visual reference ground truth
Real DJI Matrice 350 RTK (verified from djiits CDN product photo): the airframe is DARK — shell ≈ 0x474d55, arms ≈ 0x33383f, black pods, red/green arm-tip LEDs, dual battery packs rear-top, splayed legs with cross-brace, gimbal under nose. It is NOT light grey. Sci-fi look comes from glowing/neon materials — keep the airframe matte with no emissive accents.
