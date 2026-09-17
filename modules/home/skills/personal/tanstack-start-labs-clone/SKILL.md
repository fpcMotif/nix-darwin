---
name: tanstack-start-labs-clone
description: Procedure for scaffolding TanStack Start + Tailwind CSS v4 + GSAP + Matter.js 2D physics web clones matching Google Labs (https://labs.google/) with CDP verification.
---

# Procedure for Scaffolding TanStack Start + Matter.js Google Labs Clones

Procedure for creating web clones matching Google Labs (https://labs.google/) with TanStack Start, Tailwind CSS v4, and Matter.js 2D physics engine verified via Chrome CDP port 9222.

## 1. Scaffolding & Dependencies
- Scaffold TanStack Start project with React & Vite.
- Install `matter-js` and `@types/matter-js` for 2D rigid-body physics.
- Configure `vite.config.ts` with `tanstackStart()`, `@tailwindcss/vite`, and `@vitejs/plugin-react`.

## 2. Palette & Stage Specifications
- Background palette: `#F3EFEA` (off-white).
- Shape color palette:
  - Bright Green: `#48F08B`
  - Soft Pink: `#FFBDF9`
  - Vibrant Blue: `#5E9BFF`
  - Yellow Clover: `#FCC934`
  - Orange Hexagon: `#FF7328`
- Stage container: `1888px` max-width container, `380px` height stage with floor boundary line at `floorY: 360px`.

## 3. SVG-Driven Rigid-Body Physics
- Create Matter.js `Engine`, `Runner`, `Bodies`, `Composite`, `MouseConstraint`.
- Setup floor and side wall boundaries with `isStatic: true`.
- Initialize rigid bodies (square, circle, hexagon, clover/flower) matching initial stack configuration.
- Sync Matter.js body `position.x`, `position.y`, and `angle` directly to absolutely positioned SVG elements via DOM element refs inside `Events.on(engine, 'afterUpdate', updateTransforms)` without CSS transition lag:
  ```js
  domEl.style.transform = `translate3d(${b.body.position.x}px, ${b.body.position.y}px, 0px) rotate(${b.body.angle}rad) translate(-50%, -50%)`;
  ```

## 4. Header & Footer Landmarks
- Header: Real Google Labs Flask icon SVG (`M2.83462 19.2174...`), `About`, `Experiments`, `Stay connected`, Discord, Reddit, and X links.
- Product areas row: `Other teams and product areas` (`Google AI`, `Google Cloud`, `Google Research`, `Google DeepMind`).
- Display wordmark: Giant vector SVG **Google Labs** wordmark (`viewBox="0 0 1815 314"`).
- Footer legal bar: Google logo and links (`ABOUT GOOGLE`, `GOOGLE PRODUCTS`, `PRIVACY`, `TERMS`, `HELP`).

## 5. Verification via Chrome CDP
- Launch Chrome on port 9222 (`Google Chrome --remote-debugging-port=9222`).
- Set device metrics override to `1568x909`.
- Verify landmark bounds (`header`, `stage`, `productBar`, `wordmark`, `footer`) fit on-screen together.
- Capture PNG screenshot via `Page.captureScreenshot`.
