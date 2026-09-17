---
name: cdp-scroll-animation-testing
description: "Write scroll-keyframe integration tests for web apps with scroll-driven animations via Chrome CDP port 9222. Use when testing sticky sections, parallax, card-to-cube folds, or any scroll-progress-based animation. Covers CDP connection, scroll dispatching gotchas, and animation state introspection."
---

# CDP Scroll-Animation Testing

## When to use
Testing scroll-driven animations (sticky sections, parallax, card folds, progress-based transitions) in a browser via Chrome CDP.

## Key Gotchas

### 1. `position: sticky` elements have dynamic `offsetTop`
`offsetTop` for a sticky element changes once it's stuck — it tracks `scrollY`, not the original flow position. **Always cache the initial offset at mount time**, or anchor progress to an adjacent non-sticky element:

```typescript
// BAD: offsetTop changes when stuck → progress always ≈ 0
const progress = (scrollY - container.offsetTop) / totalTravel;

// GOOD: use hero section's bottom as stable anchor
const heroEl = document.querySelector('.hero-section') as HTMLElement;
const stickyStart = heroEl.offsetTop + heroEl.offsetHeight;
const progress = (scrollY - stickyStart) / totalTravel;
```

### 2. CDP `window.scrollTo()` doesn't fire scroll listeners
When calling `window.scrollTo()` via `Runtime.evaluate`, the browser may NOT fire the `scroll` event synchronously. **Always dispatch manually:**

```typescript
async function scrollTo(cdp: CDPConn, y: number): Promise<void> {
  await cdp.send('Runtime.evaluate', {
    expression: `window.scrollTo(0, ${y}); window.dispatchEvent(new Event('scroll'));`,
    returnByValue: true,
  });
  // Real browser paint delay — cannot be faked in integration tests
  await new Promise((r) => setTimeout(r, 150));
}
```

### 3. Do NOT use `awaitPromise` with `requestAnimationFrame` via CDP
`rAF`-based waits (`awaitPromise: true` on a `new Promise(r => rAF(r))`) can hang indefinitely in headless Chrome. Use a simple timeout instead.

### 4. Expose animation state via `data-*` attributes
Add dataset attributes in the scroll handler so tests can introspect animation progress without parsing canvas pixels:

```typescript
canvas.dataset.progress = progress.toFixed(4);
canvas.dataset.foldProgress = foldProgress.toFixed(4);
canvas.dataset.stickyStart = String(stickyStart);
```

## Test Structure Template

```typescript
// tests/scroll-keyframes.test.ts
import { describe, it, expect, beforeAll, afterAll } from 'bun:test';

// CDP connection helper using Promise.withResolvers
async function connectCDP(tabId: string) {
  const ws = new WebSocket(`ws://127.0.0.1:9222/devtools/page/${tabId}`);
  const { promise, resolve, reject } = Promise.withResolvers<void>();
  ws.onopen = () => resolve();
  ws.onerror = reject;
  await promise;
  // ... message-based send() using Promise.withResolvers per message
}

// Test keyframes at percentage-based scroll positions
describe('Scroll Keyframe: 50%', () => {
  it('fold animation is past halfway', async () => {
    const scrollY = stickyStart + Math.round(totalTravel * 0.5);
    await scrollTo(cdp, scrollY);
    const layout = await getLayout(cdp, scrollY);
    expect(parseFloat(layout.canvas.foldProgress)).toBeGreaterThan(0.5);
  });
});
```

## Prerequisites
1. Clone running on `localhost:5173`
2. Reference site open in Chrome
3. Chrome launched with `--remote-debugging-port=9222`
4. Run: `bun test tests/scroll-keyframes.test.ts --timeout 30000`
