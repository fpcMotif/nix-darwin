---
name: t3chat-pixel-cloning
description: "Procedure for 1:1 pixel-accurate web app cloning using Chrome CDP extraction, TanStack Start + Tailwind CSS v4, Base UI, fast cn helper, and automated visual QA scripts."
---

# T3.chat 1:1 Pixel-Accurate Web App & Landing Page Cloning Workflow

## Overview
This skill documents the exact, repeatable workflow for 1:1 pixel-accurate website and AI chat app cloning using Chrome CDP port 9222, TanStack Start + Vite, Tailwind CSS v4, Base UI, and high-performance `cnfast` class utilities.

---

## 1. Deep CDP Extraction Workflow

### Connect & Inspect Live Theme Rules
Connect to Chrome CDP on port `9222` via WebSocket:
```js
const res = await fetch("http://127.0.0.1:9222/json/list");
const targets = await res.json();
const target = targets.find(t => t.url.includes("t3.chat"));
const ws = new WebSocket(target.webSocketDebuggerUrl);
```

### Extract CSS Variables & Theme Tokens directly from Stylesheets
Key tokens extracted for T3.chat themes:
- **Dark Mode**: `--background`: `#21141e`, `--card`: `#0b080b`, `--primary`: `#a3004c`
- **Light Mode**: `--background`: `#f2e1f4`, `--card`: `#faf3fb`, `--primary`: `#e33f86`
- **Font Stack**: `ProximaVara, ui-sans-serif, system-ui, sans-serif`
- **Easing Curve**: `cubic-bezier(.2, .4, .1, .95)`

---

## 2. Replicating Signature Visual Effects & Layout Architecture

### Floating Inset Card Layout (`p-2`)
T3.chat uses a floating card inset layout structure rather than full bleed panels:
- **Sidebar Outer Wrapper**: `p-2` inset padding around the floating panel.
- **Sidebar Inner Panel**: `rounded-2xl border border-sidebar-border bg-sidebar-background shadow-sm`.
- **Top Control Pills**: `bg-sidebar-background/80 backdrop-blur-md border border-sidebar-border rounded-xl p-1` floating control containers on top-left and top-right.

### Background Radial & Noise Texture Layers
```css
/* Radial gradient glow */
.dark .bg-t3-gradient {
  background-image: radial-gradient(closest-corner at 120px 36px, rgba(255, 1, 111, 0.19), rgba(255, 1, 111, 0.08)), linear-gradient(rgb(63, 51, 69) 15%, rgb(7, 3, 9));
}

/* 96px x 96px noise overlay */
.bg-noise {
  background-image: url("https://t3.chat/images/noise.png");
  background-size: 96px 96px;
  background-repeat: repeat;
}
```

### Top Corner Skew Accent Line (`TopNoiseLine`) & Curved Notch Frame (`HeaderNotch`)
```tsx
<svg className="w-full h-12 overflow-visible pointer-events-none" viewBox="0 0 1000 48" preserveAspectRatio="none">
  <path d="M 0 12 L 780 12 C 810 12, 820 40, 850 40 L 1000 40" stroke="currentColor" strokeWidth="1.5" className="text-border" />
</svg>
```

---

## 3. Production Build & Automated Visual QA

### Production Preview Build
```bash
bun run build
bun run preview
```

### Run CDP Benchmark Visual Comparison
```bash
bun run scripts/compare-ui.js
```

Saves captured outputs to `./screenshots/`:
- `original-expanded.png`
- `original-collapsed.png`
- `clone-expanded.png`
- `clone-collapsed.png`
