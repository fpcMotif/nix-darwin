---
name: procedural-ascii-canvas-shaders
description: "Implement zero-dependency procedural ASCII canvas shaders, trigonometric domain-warping noise fields, optical glyph density ramps, and 15fps throttled Canvas 2D renderers."
---

# Procedural ASCII Canvas Shaders & Glyph Density Ramps

Procedure for building zero-dependency, real-time procedural ASCII canvas shaders and noise-modulated glyph fields in React / Canvas 2D.

## 1. The Core Analytical Noise Function
Use nested trigonometric domain warping to generate smooth, non-repeating turbulent scalar fields without heavy external noise libraries:

```ts
function field(x: number, y: number, t: number): number {
  const a = x * 0.55;
  const b = y * 0.35;
  const v =
    Math.sin(a + 2.1 * Math.sin(b * 0.9 + t) + t * 0.7) *
    Math.cos(b - 1.7 * Math.sin(a * 0.6 - t * 0.8));
  return 0.5 + 0.5 * v; // Normalized [0.0, 1.0]
}
```

## 2. Optical Glyph Density Ramps
Monotonically increasing arrays ordered by ink fill ratio:
- Subtle dissolving ramp (with leading spaces for soft edges):
  `const RAMP = [" ", " ", " ", ".", ":", ">", "~", "×", "*", "#"];`
- Standard full-range ramp:
  `const RAMP_STD = [" ", ".", ":", "-", "=", "+", "*", "%", "@", "#"];`

## 3. High-DPI Canvas 2D Setup
```ts
const CW = 12; // monospace cell width (px)
const CH = 14; // monospace cell height (px)
const dpr = Math.min(window.devicePixelRatio || 1, 2);

canvas.width = cols * CW * dpr;
canvas.height = rows * CH * dpr;
ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
ctx.font = '10px "Geist Mono", monospace';
ctx.textBaseline = "top";
```

## 4. Quantization & Drawing Loop
```ts
for (let y = 0; y < rows; y++) {
  for (let x = 0; x < cols; x++) {
    const v = field(x + offsetSeed, y, t) * falloff;
    const rampIndex = Math.min(RAMP.length - 1, Math.floor(v * RAMP.length));
    const g = RAMP[rampIndex];
    if (!g || g === " ") continue;

    ctx.fillStyle = `rgba(139, 92, 246, ${(0.16 + v * 0.5).toFixed(2)})`;
    ctx.fillText(g, x * CW + 2, y * CH + 2);
  }
}
```

## 5. Organic Framerate Pacing & Accessibility
Throttle render loop to ~15fps (~66ms frame delta) for organic text drift that saves CPU:
```ts
if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
  draw(0);
} else {
  let prev = 0;
  let animId = 0;
  const tick = (ms: number) => {
    if (ms - prev > 66) {
      prev = ms;
      draw(ms * 0.00022);
    }
    animId = requestAnimationFrame(tick);
  };
  animId = requestAnimationFrame(tick);
}
```
