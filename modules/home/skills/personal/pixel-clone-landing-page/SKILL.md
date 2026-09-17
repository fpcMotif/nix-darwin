---
name: pixel-clone-landing-page
description: Rebuild a live website's landing page as a pixel-accurate clone using raw-WebSocket CDP against an already-running Chrome (port 9222) to capture ground truth before writing any code. Trigger on "clone this landing page", "pixel-perfect clone of [site]", "recreate this UI exactly", or mentions of CDP/port 9222/agent-browser cloning.
---

# Pixel-clone a landing page via raw CDP

Methodology validated end-to-end rebuilding t3.chat's landing page into a TanStack Start +
Tailwind v4 project, landing at 1.2–1.7% pixel mismatch. The core discipline: **capture ground
truth from the live site with a real browser (CDP), write it down once, then build against the
written spec — never against memory or a single screenshot.**

No puppeteer/playwright dependency needed. Plain `fetch` + native Node `WebSocket` against
Chrome's own `--remote-debugging-port=9222` inspector protocol is sufficient and has fewer moving
parts.

## 0. Prerequisites

Chrome must already be running with `--remote-debugging-port=9222` (the user starts this; don't
launch a fresh Chrome yourself unless asked — you want *their* logged-in/authenticated tab state
where relevant, and launching a second Chrome instance on the same port will fail). Verify:

```bash
curl -s http://127.0.0.1:9222/json/version
```

## 1. Enumerate and pick a CDP target

```js
const res = await fetch('http://127.0.0.1:9222/json/list');
const targets = await res.json();
// Pick by exact URL, or id if you already found it in a prior call — id is stabler
// across re-navigations within the same tab than matching on url again.
const target = targets.find((t) => t.url === 'https://example.com/');
```

If no tab for your local dev server exists yet, open one instead of reusing a random tab:

```js
const created = await fetch(
  `http://127.0.0.1:9222/json/new?${encodeURIComponent('http://localhost:5173/')}`,
  { method: 'PUT' }
);
const cloneTarget = await created.json();
await new Promise((r) => setTimeout(r, 1000)); // give it a moment to start loading
```

Each target has a `webSocketDebuggerUrl` — that's what you connect to next.

## 2. Raw WebSocket CDP send/receive template

This is the whole plumbing layer. Copy it verbatim; you rarely need more.

```js
async function withPage(wsUrl, fn) {
  const ws = new WebSocket(wsUrl);
  await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
  let id = 1;
  const pending = new Map();
  ws.onmessage = (event) => {
    const msg = JSON.parse(event.data);
    if (msg.id !== undefined && pending.has(msg.id)) {
      const { resolve, reject } = pending.get(msg.id);
      pending.delete(msg.id);
      if (msg.error) reject(new Error(JSON.stringify(msg.error)));
      else resolve(msg.result);
    }
  };
  function send(method, params = {}) {
    return new Promise((resolve, reject) => {
      const currentId = id++;
      pending.set(currentId, { resolve, reject });
      ws.send(JSON.stringify({ id: currentId, method, params }));
    });
  }
  try { return await fn(send); } finally { ws.close(); }
}

async function evalJS(send, expression) {
  const res = await send('Runtime.evaluate', {
    expression, returnByValue: true, awaitPromise: true,
  });
  if (res.exceptionDetails) throw new Error(JSON.stringify(res.exceptionDetails));
  return res.result.value;
}

// Usage:
await withPage(target.webSocketDebuggerUrl, async (send) => {
  await send('Page.enable');
  await send('Runtime.enable');
  await send('Emulation.setDeviceMetricsOverride', {
    width: 1568, height: 908, deviceScaleFactor: 1, mobile: false,
  });

  const data = await evalJS(send, `(() => ({ title: document.title }))()`);

  await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: 800, y: 500 });
  await send('Input.dispatchMouseEvent', { type: 'mousePressed', x: 800, y: 500, button: 'left', clickCount: 1 });
  await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: 800, y: 500, button: 'left', clickCount: 1 });

  const snap = await send('Page.captureScreenshot', { format: 'png' });
  require('fs').writeFileSync('out.png', Buffer.from(snap.data, 'base64'));
});
```

Key params worth knowing: `Emulation.setDeviceMetricsOverride` pins viewport/DPR so screenshots
are reproducible across runs; `Runtime.evaluate` needs `returnByValue: true` to get a plain JS
value back (not a remote object handle) and `awaitPromise: true` if your expression is/returns a
promise; always wrap `Runtime.evaluate` expressions as `(() => { ... })()` IIFEs so `return`
works and only the final value serializes.

## 3. The critical lesson: don't trust 1–2 screenshots for UI *behavior*

This is where the original clone attempt in this project went wrong (see the sidebar case study
below), and it is the single highest-value thing this skill teaches:

- **Never screenshot immediately after connecting.** The page may be mid-animation, a hover style
  from your own cursor's last real OS position may be stuck active, or content may not have
  finished mounting. Always: move the mouse to a neutral point (e.g. dead-center of the viewport,
  away from any interactive element) via a real `Input.dispatchMouseEvent{type:'mouseMoved'}`,
  then `await sleep(≥300–400ms)`, *then* screenshot. Call this your baseline, and only trust it as
  ground truth for the "default" state.
- **Explicitly separate hover-only from click-triggered behavior.** Don't infer "this must be a
  hover-peek panel" from a screenshot that happens to show it partially visible — that's very
  plausibly just a mid-transition frame from click-driven state, caught by an ill-timed shot. Test
  both paths for real:
  - Hover-only: `mouseMoved` to the element, `sleep(500)`, screenshot, then read computed styles.
    Do **not** dispatch `mousePressed`/`mouseReleased`. If nothing changed, hover does nothing.
  - Click-triggered: `mouseMoved` → `mousePressed` → `mouseReleased` (a real press/release pair,
    not a synthetic `.click()` via `Runtime.evaluate`, which can skip CSS `:hover`/`:active` state
    and any event-timing-sensitive JS), `sleep(≥ measured-transition-duration + 250ms margin)`,
    *then* move the mouse away to neutral and `sleep` again before screenshotting/reading styles —
    this distinguishes "settled after click" from "still hovering the thing you just clicked,"
    which can itself carry a different style.
  - Only conclude a mechanism ("hover-peek overlay" vs "click-toggled offcanvas" vs "push-layout")
    after you've dispatched both event sequences separately and diffed the *computed style / DOM
    attribute* output, not just eyeballed screenshots.
- **Re-read computed styles after every state mutation**, not just at the start. A property like
  `transform` that looks like a reliable state signal on your assumption of the site's markup can
  be `"none"` in *both* states on a real, differently-implemented page (this happened: the actual
  hide mechanism turned out to be a zero-width `overflow:hidden` ancestor clip, not a
  `translateX`, and `Element.checkVisibility()` on interior content returned `true` either way). A
  DOM `data-state`/`data-*` attribute on a stable wrapper element is usually a more reliable signal
  than any single computed CSS property — check for one before relying on style-sniffing.
- Batch state-detection logic as a reusable `evalJS` snippet you re-run before *and* after each
  mutation, so every conclusion is backed by paired before/after readings, not vibes from a diff of
  two PNGs.

## 4. Batch-extract design tokens in one `Runtime.evaluate` call

Don't read the live site's raw stylesheet / CSS custom-property declarations directly — a
multi-theme site (dark/light/system, A/B variants) can have inactive theme rules sitting in the
cascade that don't reflect what's actually rendered. **Computed styles on real, currently-visible
elements are ground truth; declared stylesheet rules may not be.**

Instead, find representative elements by `textContent`/attribute matching (robust) rather than CSS
selectors guessed from class names (fragile — utility-class names get purged/renamed by build
tools and don't survive across a redesign), then pull `getComputedStyle` + `getBoundingClientRect`
for all of them in a single call:

```js
const tokens = await evalJS(send, `(() => {
  const byText = (tag, needle) => Array.from(document.querySelectorAll(tag))
    .find(el => el.textContent?.trim().toLowerCase().includes(needle));
  const targets = {
    primaryButton: byText('button', 'new chat'),
    heading: document.querySelector('h1'),
    input: document.querySelector('textarea, input[type="text"]'),
  };
  const out = {};
  for (const [key, el] of Object.entries(targets)) {
    if (!el) { out[key] = null; continue; }
    const cs = getComputedStyle(el);
    const r = el.getBoundingClientRect();
    out[key] = {
      color: cs.color, backgroundColor: cs.backgroundColor, borderColor: cs.borderColor,
      fontSize: cs.fontSize, fontWeight: cs.fontWeight, lineHeight: cs.lineHeight,
      borderRadius: cs.borderRadius, padding: cs.padding, transition: cs.transition,
      rect: { w: r.width, h: r.height },
    };
  }
  return out;
})()`);
```

One round trip, one JSON object, no risk of picking the wrong theme variant. Note that colors will
often come back as `oklab(...)`/`oklch(...)` with a fractional alpha (e.g.
`oklab(0.46 0.18 0.01 / 0.2)`) rather than flat hex — that's a real signal, not noise (see
Reflection notes on why sites do this); replicate it as a translucent color, not a solid
approximation.

## 5. Vector paths and defaults need verification too, not just colors/spacing

Colors, padding, and timing get the most attention because they're the easiest to eyeball-check
in a screenshot — but two other classes of bug slip through exactly *because* they look plausible
at a glance:

- **Never hand-trace or approximate a logo/icon SVG path from a screenshot.** A path that's
  "roughly the right shape" can render as visibly garbled text (an actual case from this project:
  a wordmark path that was correct for the first ~35% of its `d` string and subtly wrong after
  rendered as garbled letters, at *any* zoom level — not an anti-aliasing artifact). If the source
  DOM has the real element, pull its exact `d` attribute (or full `outerHTML`) over CDP and diff it
  **character-for-character** against what you're about to ship:
  ```js
  const real = await evalJS(send, `document.querySelector('svg[viewBox="..."] path').getAttribute('d')`);
  // then: real === candidateD  — not "looks similar", an exact string comparison.
  ```
  "Looks about right" is not verification for path data the way it can be for a color you can
  re-measure and visibly compare; a wrong curve command doesn't degrade gracefully.
- **Don't invent a component's default/rest state from vibes.** `useState(true)` for a toggle that
  "feels like it should probably default on" is exactly the kind of unverified guess that survives
  code review because it's plausible. Read the real element's resting computed style
  (`backgroundColor`, `border`, etc. with the mouse elsewhere and nothing clicked) before choosing
  a default value, the same way you'd verify a color.
- **A screenshot-read color is not a substitute for `getComputedStyle`.** Eyeballing a compressed
  PNG can misread a neutral gray as green or a specific value as a different nearby brand color —
  both wrong guesses are equally confident-looking. If a value matters, read it with
  `getComputedStyle`, even for something as small as a single badge's text color.

## 6. Licensing caution

- **Never copy a target site's self-hosted commercial webfont binaries** (`.woff2`/`.woff`/`.ttf`)
  into your new project. A commercial font's license covers the original site's domain, not
  redistribution into an unrelated project. Instead: declare the correct `font-family` stack
  (brand font name first, full system fallback stack after) in CSS/Tailwind config, and leave a
  code comment noting the caveat — it renders correctly for anyone who happens to already have the
  font installed/licensed, and degrades gracefully otherwise. If pixel-exact typography genuinely
  matters, tell the user to acquire their own license and drop the files in themselves.
- **Never hotlink a live target's asset URLs** (images, textures, icons served from their domain)
  into the clone — that's a live runtime dependency on someone else's server, plus generally an
  ToS/hotlinking concern. Inline as a local data-URI, regenerate as an equivalent (e.g. an SVG
  `feTurbulence` filter in place of a noise-texture PNG), or note it as a manual follow-up.

## 7. Recommended phase structure for the actual rebuild

Once ground truth is captured and written down (step 7), structure the build as:

1. **Theme/token foundation — single agent.** CSS custom properties, Tailwind theme config, font
   stack, base color tokens. Everything downstream depends on this; parallelizing it just causes
   merge conflicts on the same few files.
2. **Parallel per-surface component rebuild — multiple agents, disjoint files.** Split by visual
   surface (sidebar, header, prompt card, suggestion pills, etc.), each agent owning files no other
   agent touches. Explicitly instruct every agent to **preserve existing prop interfaces/exported
   component signatures** — this is what lets several agents edit sibling files concurrently
   without one agent's refactor breaking another's import.
3. **Magic-number/hardcoded-string audit + typecheck pass — single agent.** Sweep for values that
   should have come from the token foundation but got hardcoded locally during parallel work
   (duplicate color literals, one-off spacing, a stray font-family), then run the type checker.
4. **Pixel-diff verification pass.** `pixelmatch`/`pngjs` comparing real screenshots of the live
   site against the clone's dev server, for every state that matters (e.g. sidebar
   expanded/collapsed) — see the CDP screenshot pattern in step 2. Report the honest mismatch
   percentage; don't round away remaining gaps or claim pixel-perfect without a number to back it.
5. **Reflection.** Write down what the target's frontend does well worth learning from, what
   assumption in your own process turned out wrong and why, and concrete numeric corrections
   (exact px/ms/alpha values) for next time — this is what step 7's ground-truth doc should already
   contain in polished form; the reflection is about *process*, the spec is about *facts*.

## 8. Write a ground-truth spec doc — don't re-probe per agent

Once you've captured colors, spacing, typography, transition timings, and behavioral findings
(steps 3–4), **write them to a single Markdown file** (e.g. `docs/ground-truth-spec.md`) before
spinning up any implementation agents. Every agent in phase 2 reads this file instead of
re-connecting to the live site itself. Reasons this matters, not just tidiness:

- Multiple agents independently driving `Input.dispatchMouseEvent` against the *same* shared
  live browser tab race each other and corrupt each other's state (one agent's "click toggle" can
  fire while another is mid-read).
- Different agents probing at different times can get inconsistent findings if the live site is a
  multi-theme/A-B-tested/session-dependent page.
- A written spec is reviewable — a human (or a future you) can sanity-check the extracted numbers
  once, in one place, instead of trusting N separate probing sessions.

Format that worked well: one markdown file, grouped by surface/concern, each fact stated as
**measured value → what it corrects in the existing clone**, plus an explicit "known gaps — verify
live before touching" section for anything not yet probed, so implementation agents know what's
solid ground truth versus what still needs a live check.
