---
name: cdp-style-extraction-cloning
description: "Extract pixel-exact CSS computed styles, layout metrics, and DOM structure from a live website via bunx agent-browser CDP eval, then use those values to build a matching clone. Use when cloning a website pixel-by-pixel, doing visual QA against a reference site, or extracting design tokens from a live page."
---

# CDP Style Extraction for Pixel-Perfect Cloning

## When to Use
- Cloning a website pixel-by-pixel
- Extracting exact design tokens (colors, fonts, spacing, radii) from a live page
- Visual QA comparing a clone against the original

## Procedure

### 1. Open the target site
```bash
bunx agent-browser open https://target-site.com/
bunx agent-browser wait 3000
```

### 2. Get the accessibility tree for structure
```bash
bunx agent-browser snapshot -d 4
```
This reveals the **exact semantic structure**: sections, headings, regions, navigation, carousels, tabs, landmarks. Match this structure first — layout trumps styling.

### 3. Extract computed styles via CDP eval
Use `bunx agent-browser eval` with an IIFE returning `JSON.stringify(...)`. Key pattern:

```js
bunx agent-browser eval "(() => {
  const g = (el, prop) => window.getComputedStyle(el)[prop];
  const rect = (el) => { const r = el.getBoundingClientRect(); return { w: Math.round(r.width), h: Math.round(r.height) }; };

  const header = document.querySelector('header');
  return JSON.stringify({
    position: g(header, 'position'),
    height: header.getBoundingClientRect().height,
    bg: g(header, 'backgroundColor'),
    backdropFilter: g(header, 'backdropFilter'),
    zIndex: g(header, 'zIndex'),
    navFontSize: g(header.querySelector('a'), 'fontSize'),
    navFontWeight: g(header.querySelector('a'), 'fontWeight'),
    navColor: g(header.querySelector('a'), 'color')
  }, null, 2);
})()"
```

### 4. Key properties to always extract
- **Layout**: `position`, `display`, `flexDirection`, `gridTemplateColumns`, `gap`, `overflow`
- **Box model**: `width`/`height` (via `getBoundingClientRect()`), `padding`, `margin`, `borderRadius`, `border`
- **Visual**: `backgroundColor`, `color`, `boxShadow`, `backdropFilter`, `opacity`
- **Typography**: `fontSize`, `fontWeight`, `fontFamily`, `lineHeight`, `letterSpacing`
- **Card-specific**: `aspectRatio`, `overflow`, media container dimensions and border-radius

### 5. Scroll to reveal lazy-loaded sections
```bash
bunx agent-browser scroll down 800
bunx agent-browser wait 2000
# Then extract again for below-fold content
```

### 6. Visual diff comparison
```bash
bunx agent-browser diff url https://original.com/ http://localhost:3000/
```

### 7. Verify clone metrics match
Run the same extraction script on your clone and compare values:
```bash
bunx agent-browser open http://localhost:3000/
bunx agent-browser eval "(() => { /* same extraction */ })()"
```

## Critical Learnings
- **Structure first**: Get the accessibility snapshot to understand if it's a carousel vs grid, absolute vs sticky header, etc. Wrong structure = wrong clone regardless of CSS.
- **Scroll position matters**: Many sites use position:absolute headers that overlay hero sections — check `position`, not just background.
- **Video/media**: Extract `video.src`, `img.src` directly from DOM for exact asset URLs.
- **Font rendering**: Google Sans is loaded from fonts.googleapis.com; preconnect + stylesheet link required.
- **className may be SVGAnimatedString**: Guard with `typeof el.className === 'string'` when iterating DOM.
