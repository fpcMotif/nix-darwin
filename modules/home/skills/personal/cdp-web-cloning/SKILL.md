---
name: cdp-web-cloning
description: "Inspect, extract assets, CSS keyframe animations, and build pixel-accurate web app clones using Chrome CDP port 9222 and Bun."
---

# CDP Web Cloning & Visual Inspection

Use this skill when tasked with inspecting, extracting assets, CSS rules, keyframe animations, and DOM structures from a target website via Chrome CDP port 9222 to build a 1:1 pixel-accurate clone.

## Procedure

1. **Launch Target Site in Chrome CDP Port 9222**:
   ```bash
   "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-cdp-session "https://target-url.com"
   ```

2. **Inspect DOM Tree & Extract All CSS Rules via CDP**:
   Connect via WebSocket to the CDP endpoint (`http://127.0.0.1:9222/json/list`) and run `Runtime.evaluate` to dump:
   - Computed styles and DOM tree (`document.body`)
   - Style rules and `@keyframes` animations (`document.styleSheets`)
   - CSS variables and theme properties (`window.getComputedStyle(document.documentElement)`)

3. **Scaffold React + TanStack Router + Tailwind CSS v4 Project**:
   ```bash
   bun create vite my-clone --template react-ts
   cd my-clone
   bun add @tanstack/react-router lucide-react three clsx tailwind-merge
   bun add -D tailwindcss @tailwindcss/vite
   ```

4. **Implement Animation & Visual Engine**:
   - Replicate `.shine` glowing offset-path border animations (`offset-path: border-box`, `@keyframes trail`).
   - Replicate scroll-choreographed 3D WebGL / Three.js canvas sections (`position: sticky; top: 0; height: 1100px;`).
   - Implement responsive desktop/mobile viewports (`block lg:hidden` vs `hidden lg:block`).

5. **Aligned Side-by-Side Visual Verification**:
   - Force both CDP tabs to `window.scrollTo(0, 0)` and match theme modes.
   - Set device metrics override to Desktop (`1440x900`) and Mobile (`390x844`).
   - Capture side-by-side PNG screenshots for fidelity verification.
