---
name: cdp-hover-extraction
description: "Extract and replicate mouse hover effects from a target website via Chrome CDP. Use when cloning hover states, interactive transitions, or verifying hover fidelity between a target site and a clone."
---

# CDP Hover Effect Extraction & Verification

## When to Use
- Cloning hover interactions from a target website
- Verifying hover fidelity between original and clone
- Extracting transition/transform/opacity hover behaviors via CDP

## Procedure

### 1. Extract All Hover CSS Rules
```js
// Via tab.evaluate in browser tool
const hoverRules = [];
for (const sheet of document.styleSheets) {
  try {
    for (const rule of sheet.cssRules) {
      if ((rule.cssText || '').includes(':hover')) {
        hoverRules.push(rule.cssText.slice(0, 300));
      }
    }
  } catch(e) {}
}
```

### 2. Extract Hover-Related CSS Variables
Key variables to look for:
- `--theme-button-states-primary-hovered`
- `--theme-button-secondary-hover`
- `--theme-button-states-hovered`
- `--theme-nav-button-hover`
- `--theme-surface-surface-container-high`
- `--theme-outline-variant`

### 3. Extract Interactive Element Base Styles
For each interactive element, capture:
- `transition` (e.g., `0.15s ease-out`, `transform 0.3s, opacity 0.3s`)
- `cursor` (pointer, not-allowed)
- `borderRadius`
- `backgroundColor`
- `boxShadow`
- `transform`

### 4. Common Hover Patterns

**Button hover** — bg color change with `transition: 0.15s ease-out`:
```css
.button-primary:hover { background: var(--hovered-bg); }
```

**Video play button** — parent hover fades/shrinks child:
```css
.video-wrapper:hover .video-control-button {
  opacity: 0;
  transform: scale(0.8);
}
```

**Arrow link** — `::after` pseudo slides on hover:
```css
.arrow-link::after {
  content: 'keyboard_arrow_right';
  font-family: "Google Symbols";
  transition: transform 0.3s;
}
.arrow-link:hover::after {
  transform: translateX(50%);
}
```

**Footer links** — color + underline:
```css
.footer-link:hover {
  color: var(--on-surface);
  text-decoration: underline;
}
```

### 5. Verify Hover Effects via CDP
Simulate hover by moving mouse and checking computed styles:
```js
// Move mouse to element
const el = await tab.waitForSelector('.button-primary');
const box = await el.boundingBox();
await page.mouse.move(box.x + box.width/2, box.y + box.height/2);
await new Promise(r => setTimeout(r, 300));

// Check computed hover state
const hoverBg = await tab.evaluate(() => {
  const el = document.querySelector('.button-primary:hover');
  return el ? window.getComputedStyle(el).backgroundColor : 'no hover';
});
```

For parent-child hover (e.g., wrapper hover affecting child):
```js
// Move to parent corner (away from child)
await page.mouse.move(parentBox.x + 50, parentBox.y + 50);
// Then check child's computed styles
```

### 6. Best Practices
- **CSS classes over JS handlers**: Replace `onMouseEnter`/`onMouseLeave` with pure CSS `:hover` rules
- **Use CSS custom properties**: Map target hex values to OKLCH equivalents for the clone
- **Test both direct and inherited hover**: A child's hover state may depend on parent `:hover`
- **Check `::after`/`::before` pseudo-elements**: Many hover effects use pseudo-element transitions
- **Disabled state**: Don't forget `:hover:not(:disabled)` for interactive controls
