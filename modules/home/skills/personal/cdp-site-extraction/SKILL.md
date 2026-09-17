---
name: cdp-site-extraction
description: "Extract exact DOM structure, computed CSS, media URLs, layout metrics, and experiment/card data from a live website using bunx agent-browser CDP eval for pixel-accurate cloning. Use when cloning a website, extracting design tokens, or doing visual QA against a reference site."
---

# CDP Site Data Extraction for Pixel-Accurate Cloning

## When to Use
- Cloning a website pixel-by-pixel
- Extracting design tokens (colors, fonts, spacing, radii) from a live page
- Visual QA comparison between a clone and reference site
- Extracting real media asset URLs (images, videos, posters) from a live site

## Tooling
- `bunx agent-browser open <url>` — open a page
- `bunx agent-browser wait <ms>` — wait for lazy content
- `bunx agent-browser scroll down <px>` — scroll to trigger lazy loading
- `bunx agent-browser eval "<js>"` — run JS in page context, returns JSON
- `bunx agent-browser snapshot -d <depth>` — accessibility tree snapshot

## Extraction Workflow

### 1. Map Page Sections
```js
bunx agent-browser eval "(() => {
  const allH = Array.from(document.querySelectorAll('h1, h2, h3, h4'));
  return allH.map(h => ({
    tag: h.tagName,
    text: h.innerText?.trim()?.substring(0, 80),
    parentClass: (typeof h.parentElement?.className === 'string' ? h.parentElement.className : '').substring(0, 60),
    gpClass: (typeof h.parentElement?.parentElement?.className === 'string' ? h.parentElement.parentElement.className : '').substring(0, 60)
  }));
})()"
```

### 2. Extract Computed Styles
```js
const g = (el, prop) => window.getComputedStyle(el)[prop];
// fontSize, fontWeight, fontFamily, color, lineHeight, letterSpacing
// backgroundColor, borderRadius, padding, margin, gap, display, flexDirection
// border, boxShadow, backdropFilter, overflow, position, zIndex
```

### 3. Extract Card/Item Data with Media URLs
Walk UP from title elements to find card containers:
```js
const titleEls = Array.from(container.querySelectorAll('h2, h3'));
for (const h of titleEls) {
  let card = h.parentElement;
  // Walk up to find the card wrapper
  const video = card.querySelector('video');
  const videoSrc = video?.querySelector('source')?.src || video?.src || '';
  const poster = video?.getAttribute('poster') || '';
  const img = card.querySelector('img')?.src || '';
  const href = card.querySelector('a[href]')?.getAttribute('href') || '';
}
```

### 4. Scroll + Re-extract for Lazy Content
Cards/images may lazy-load. Scroll down and wait before extracting:
```
bunx agent-browser scroll down 2000
bunx agent-browser wait 2000
bunx agent-browser eval "..."
```

## Critical Rules
- NEVER fabricate media URLs. Every poster, video, and image URL must come from CDP extraction.
- NEVER map one experiment's media to another. Each card's media belongs only to that card.
- Relative URLs (starting with `/`) need the origin prepended: `https://domain.com${relativePath}`
- Use `typeof el.className === 'string'` guard — SVG elements have non-string className.
- `video.readyState === 4` means loaded; check after wait.

## Verification
After building the clone, verify every media URL appears correctly:
```bash
curl -s http://localhost:3000/ | grep -o 'https://original-site.com/assets/[^"]*' | sort -u
```
Compare this list against the extraction output — they must match 1:1.
