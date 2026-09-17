---
name: webgl-particle-cursor-cloning
description: "Extract WebGL particle shaders, color palettes, and GSAP custom cursor follower interactions from live websites via CDP inspection"
---

# WebGL Particle & Custom Cursor Site Extraction Protocol

Procedure for extracting WebGL shaders, particle parameters, and GSAP custom cursor follower interactions from live Astro / Vite websites via CDP port 9222.

## 1. Inspect & Extract Astro Bundle JS Files
When cloning sites built with Astro or Vite:
```js
const scripts = Array.from(document.querySelectorAll('script'))
  .map(s => s.src)
  .filter(s => s.includes('_astro') || s.includes('bundle'));
```
Fetch the bundle JS files directly using `fetch(scriptUrl)` via `tab.evaluate()` or `bunx agent-browser eval`.

## 2. Extract WebGL Shader & Particle Math
Look inside particle component bundles (`MainParticlesComponent`, etc.):
- **Colors**: Search for `colorControls` or `uColor1`, `uColor2`, `uColor3`.
- **Count & Density**: Search for `density`, `particleScale`, `size`.
- **Simplex Noise & Physics**: Extract vertex/fragment shaders containing `snoise` or `sdRoundBox`.
- **Mouse Tracking**: Search for `intersectionPoint` or `raycastPlane` logic to replicate gravitational pull.

## 3. Replicate GSAP Custom Cursor Follower (`CustomCursor`)
Target sites using custom mouse follower badges (`.custom-cursor`) use GSAP `quickTo`:
```ts
const quickX = gsap.quickTo(cursor, 'x', { duration: 0.35, ease: 'power2.out' });
const quickY = gsap.quickTo(cursor, 'y', { duration: 0.35, ease: 'power2.out' });
```
- On `mouseenter`: `container.style.cursor = 'none'`, `gsap.to(cursor, { scale: 1, opacity: 1, duration: 0.3, ease: 'back.out(1.7)' })`.
- On `mouseleave`: `container.style.cursor = ''`, `gsap.to(cursor, { scale: 0, opacity: 0, duration: 0.2, ease: 'power2.in' })`.
- On `mousemove`: compute relative offset inside container bounds, call `quickX(x)` and `quickY(y)`.
