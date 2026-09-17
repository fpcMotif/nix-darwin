---
name: react-vite-singlefile-html
description: "Procedure for bundling and inlining a React + Vite project into a self-contained single HTML file with zero path leaks, optimized base64 assets, and full interactivity."
---

# Packaging a React + Vite Project into a Standalone Single-File HTML

Use this procedure to merge or export an existing React (Vite + Tailwind CSS) project into a single, self-contained `.html` file that can be opened via `file://` or emailed/messaged directly with zero dependencies.

## Key Invariants
1. **Zero Path Leaks**: Never leave local machine paths (`/Users/...`, `C:\...`, `file://...`) in the HTML or JS bundle.
2. **Preload Tag Safety**: React 19 SSR emits `<link rel="preload" as="image" href="...">` tags. Ensure these use base64 data URIs or are sanitized.
3. **Asset Inlining**: Replace local image paths in both the static HTML DOM and the compiled JS bundle (`dist/assets/index-*.js`) with base64 data URIs.
4. **Image Optimization**: High-resolution camera imports (e.g. 50MP JPEGs / large PNGs) should be resampled for web display (e.g. 1200–1600px width with 85–88% JPEG quality) before base64 encoding to keep the final HTML file lightweight.
5. **Combined SSR + Client Hydration**: Embed the pre-rendered static HTML inside `<div id="root">` for instant no-flicker display, while inlining the compiled JS bundle in `<script type="module">` for full client interactivity.

## Step-by-Step Procedure

### 1. Build the Production Distribution
```bash
bun run build # or vite build
```

### 2. Prepare Asset Map & Inlining Script
Create a node/bun script that:
- Reads `dist/assets/` to find the compiled `.css` and `.js` bundles.
- Converts local image assets into optimized base64 data URIs.
- Replaces asset filename references in the JS bundle with the data URIs.
- Renders the React App with `react-dom/server`'s `renderToString` and replaces image `src` and preload `href` attributes with the base64 data URIs.
- Inlines CSS into `<style>` and JS into `<script type="module">`.

### 3. Verification Checks
Run an automated verification script:
- Check for any leaked local paths: `html.match(/\/Users\/[^\s\"\'<>]+/g)` -> must be 0.
- Check for unbundled asset paths: `html.match(/[\"\'\(\`]\/?assets\/[^\s\"\'\`\)]+/g)` -> must be 0.
- Check all `<img>` src attributes point to `data:` or HTTPS URLs.
