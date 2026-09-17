---
name: oklch-color-conversion
description: "High-precision OKLCH color space conversion procedure for web apps, CSS variables, and WebGL / Three.js canvas components while maintaining 100% sRGB round-trip pixel identity."
---

# OKLCH Color Space Conversion & Round-Tripping

## Overview
Procedure for converting sRGB (hex, RGB, RGBA) colors to high-precision OKLCH color space (`oklch(L C h [/ alpha])`) for CSS variables, SVG attributes, and WebGL / Three.js contexts while maintaining 100% sRGB round-trip pixel identity.

## Mathematical Transformation
Uses Björn Ottosson's official direct linear-sRGB → LMS → OKLab matrix transformation:

1. **Linearize sRGB**:
   $$c_{\text{linear}} = \begin{cases} \frac{c}{12.92} & \text{if } c \le 0.04045 \\ \left(\frac{c + 0.055}{1.055}\right)^{2.4} & \text{otherwise} \end{cases}$$

2. **Linear sRGB to LMS**:
   $$\begin{bmatrix} l \\ m \\ s \end{bmatrix} = \begin{bmatrix} 0.4122214708 & 0.5363325363 & 0.0514459929 \\ 0.2119034982 & 0.6806995451 & 0.1073969566 \\ 0.0883024619 & 0.2817188376 & 0.6299787005 \end{bmatrix} \begin{bmatrix} r_{\text{linear}} \\ g_{\text{linear}} \\ b_{\text{linear}} \end{bmatrix}$$

3. **LMS' to OKLab**:
   $$\begin{bmatrix} L \\ a \\ b \end{bmatrix} = \begin{bmatrix} 0.2104542553 & 0.7936177850 & -0.0040720403 \\ 1.9779984951 & -2.4285922050 & 0.4505937099 \\ 0.0259040371 & 0.7827717662 & -0.8086757973 \end{bmatrix} \begin{bmatrix} \sqrt[3]{l} \\ \sqrt[3]{m} \\ \sqrt[3]{s} \end{bmatrix}$$

4. **OKLab to OKLCH**:
   $$C = \sqrt{a^2 + b^2}, \quad h = \operatorname{atan2}(b, a) \pmod{360^\circ}$$

## Rules for Web & WebGL
- **CSS Variables & Inline Styles**: Use `oklch(L C h [/ alpha])` strings.
- **`color-mix`**: Use `color-mix(in srgb, var(--a) 70%, var(--b))` with OKLCH endpoints to preserve exact linear sRGB mixing curves.
- **Three.js & Canvas 2D**: Convert OKLCH `{L, C, h}` to `oklchToHex(L, C, h)` or `oklchToCanvasStyle(L, C, h, alpha)` via sRGB gamma conversion.
- **Code Samples & Text**: Keep code sample text strings untouched.
