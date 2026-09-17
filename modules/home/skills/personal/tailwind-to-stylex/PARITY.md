# Parity harness

`scripts/parity.ts` proves two builds of a web UI render identically: every element's computed style in the default state and under forced `:hover` / `:focus-visible` / `:active`, in each colour scheme, after scripted interactions, plus pixel screenshots. It talks raw Chrome DevTools Protocol, so it works for anything Chrome can load: SPA, SSR app, static site, Storybook, Electron renderer, browser extension. Copy it into the project (`pixelmatch` and `pngjs` as dev dependencies; run with the project's TypeScript runner — `bun`, `npx tsx`, `node --experimental-strip-types`).

A **parity round** = build candidate → capture baseline → capture candidate → compare.

```
<runner> scripts/parity.ts capture --config parity.config.json --out <dir> <host>
<runner> scripts/parity.ts compare --config parity.config.json --baseline <dir> --candidate <dir> [--report <html>]
```

## Hosts

| Host | Use for | Notes |
|---|---|---|
| `--serve <build dir>` | any static build: Vite/webpack `dist`, `next export` `out`, SSG output, Storybook `storybook-static` | the harness serves the directory on a free port (index.html fallback for client routes) and launches headless Chrome. Keep the baseline and candidate build directories side by side and capture each. |
| `--url <base>` | a running server: `next start`, `remix-serve`, `vite preview`, a staging URL; or `file:///…/index.html` | headless Chrome; the scenario `path` is joined to the base (an absolute URL in `path` is used verbatim). Capture **production builds**, whatever the stack: Vite's dev server injects CSS as per-module `<style>` tags in a different order from the extracted build stylesheet, and Next's docs say CSS order can differ under `next dev`. If a dev server is the only option, use the same dev server for both captures and set Vite's `server.hmr.overlay: false` so an error overlay cannot cover the page. Storybook: `--url http://localhost:6006` with paths `iframe.html?id=<story-id>&viewMode=story` — one scenario per story, good for component libraries, not a substitute for page-level parity (composed layouts and page CSS are not exercised). |
| `--cdp <port> --url|--serve …` | a Chrome, Chromium, or Electron the user already runs with `--remote-debugging-port=<port>` | pages open as hidden targets (Chrome ≥ 134): rendered and screenshotted, never shown or focused; older Chromium/Electron builds fall back to background tabs activated briefly per capture. The attached browser build is logged from the `/json/version` endpoint. Electron: add the flag via `app.commandLine.appendSwitch` or the launch command, then `--url` the renderer's URL (`http://localhost:…` in dev, `file:///…/index.html` in a packaged build). A harness-created target has no `BrowserWindow` preload, so a renderer that needs `contextBridge` APIs (`window.api`) renders its error or empty state — stub those APIs in `resetScript` (it runs before the page's own scripts) and confirm the baseline screenshots show the real UI. |
| `--cdp <port> --ext-id <id> [--reload]` | an unpacked browser extension loaded in that Chrome | paths resolve inside `chrome-extension://<id>/`; `chrome.storage` is snapshotted, cleared per scenario, restored at the end; `--reload` re-reads the extension directory after a build is swapped in place. |
| `--launch <unpacked extension dir>` | headless Chrome with an extension | needs a Chromium that honours `--load-extension` (Chrome for Testing); branded Chrome ≥ 137 ignores it. |

Chrome binary: `CHROME_PATH`, else the platform default. Capture baseline and candidate with the **same binary on the same machine**: a different Chrome build enumerates different properties and rasterises text a fraction of a pixel differently, which reads as hundreds of diffs. For reproducibility pin Chrome for Testing (`npx @puppeteer/browsers install chrome@<version>`) and point `CHROME_PATH` at it; the harness already pins sRGB, disables LCD text and font hinting, hides scrollbars, and emulates `hover: hover` / `pointer: fine`. Pixel diffs use `pixelmatch` (pin 7.x; the unreleased upstream rewrite changes the colour metric and any tuned threshold).

WebKit/Safari and Tauri's WKWebView/WebKitGTK expose no CDP (Tauri on Windows uses Chromium-based WebView2 and does): run the same UI in Chromium to validate the CSS refactor, and check the real WebKit engine through `safaridriver` (W3C WebDriver against system WebKit) or Playwright's bundled WebKit as a smoke test; neither is the app's own WKWebView, so neither proves WebKit parity.

## Config

```json
{
  "viewport": { "width": 1280, "height": 900 },
  "schemes": ["light", "dark"],
  "darkMode": { "mode": "class", "selector": "html", "value": "dark" },
  "resetScript": "localStorage.clear(); localStorage.setItem('theme', window.__parityScheme)",
  "readyScript": "document.querySelector('[data-hydrated]') ? true : new Promise(r => setTimeout(r, 800))",
  "settledSelectors": ["[data-loading]", ".skeleton"],
  "quietMs": 300,
  "stateTargets": "button, a[href], input, select, textarea, [role=\"switch\"], [role=\"checkbox\"], [role=\"option\"], [role=\"menuitem\"], [role=\"tab\"], [tabindex]",
  "ignoreAttributes": ["data-divide", "data-rows"],
  "scenarios": [
    { "name": "home", "path": "/" },
    { "name": "home_narrow", "path": "/", "viewport": { "width": 560, "height": 900 } },
    { "name": "settings_menu", "path": "/settings", "steps": ["await __parity.click('button', 'Menu')", "await __parity.sleep(400)", "__parity.blur()"] },
    { "name": "delete_armed", "path": "/settings", "steps": ["await __parity.click('button', 'Delete')", "await __parity.sleep(500)", "__parity.freezeClock()", "__parity.blur()"] }
  ]
}
```

- **schemes**: each scenario runs once per scheme (`name__light`, `name__dark`). Drop `dark` if the app has no dark mode.
- **darkMode**: `media` (default) emulates `prefers-color-scheme`; `class` / `attribute` also keep `value` on `selector` (default `html`) for dark scenarios and off for light ones, through the first seconds of boot. `window.__parityScheme` holds the scenario's scheme so `resetScript` can seed a theme key.
- **resetScript**: runs before every page boots (web hosts): clear storage, seed fixtures, force a locale, stub a preload bridge. **cookies**: `[{ name, value, url | domain, path?, secure?, httpOnly?, sameSite? }]` set before every page (each deleted by name first) — session and auth fixtures for apps that gate on a cookie.
- **readyScript**: a page-side expression awaited before steps — the hydration hook for SSR apps (a flag your root sets after mount, a framework promise, or a delay). Fonts (`document.fonts.ready`) are awaited always.
- **settledSelectors**: loading markers that must be gone; **quietMs**: the DOM-mutation-free window that must pass (capped at 8 s so a live clock still captures; `0` disables).
- **steps**: page-side JS strings awaited in order. Helpers: `__parity.click(sel, text?)`, `byText`, `toggle(idOrSel)` (clicks the switch/checkbox itself or the role element beside a hidden native input), `type(sel, value)` (sets through the prototype setter so React sees it), `sleep(ms)`, `freezeClock()`, `blur()`.
- **stateTargets**: every match gets `:hover`, `:focus-visible`, `:active`, `:hover:active` forced with transitions and animations disabled for the sweep; include the project's own interactive selectors.
- **ignoreAttributes**: attributes the migration adds on purpose (structural `data-*`); `class` and hashed head asset URLs are always ignored.
- **ignoreCustomProperties**: regex of custom properties that are plumbing, defaulting to Tailwind's `--tw-*` and v4 theme scale. Design tokens the UI reads (`--primary`, `--radius`) are compared.
- **viewport** per scenario for each breakpoint the app uses; **deviceScaleFactor** default 2. Container queries (`@container`, `@sm:` inside a named container) track an ancestor's width, not the viewport: add scenarios whose `steps` resize that ancestor (`document.querySelector('[data-panel]').style.width = '420px'`) across each threshold the ground truth declares.

Extension-only: scenario `tabContext` (URL the popup believes is the active tab).

## Reading the diff

`compare` prints per-scenario counts and up to 80 lines each, writes `diffs.json` and coral `diff/*.png`, and exits 2 on any difference. Group `diffs.json` by property and by `(before → after)` first — one root cause usually explains hundreds of lines (a token, a specificity rule, a line-height).

## Artefacts (differences that are not styling bugs)

- **Frozen transitions**: a page dumped while its tab was in the background reads every transitioning property at its start value (dark colours stuck on light, hovers stuck). The harness only dumps foreground or hidden targets.
- **Mid-transition reads under forced states**: solved by the injected no-motion style during the sweep; the default dump still compares `transition-*` properties.
- **`:focus-visible` after a scripted click** depends on the page's input history: `__parity.blur()` after arming steps and rely on the forced sweep for focus styles.
- **Wall-clock UI** (auto-dismiss, countdown underlines) changes during the sweep: `__parity.freezeClock()` after the step that arms it.
- **The real mouse** resting over a visible window leaves an element hovered: the harness parks the pointer; hidden targets avoid it entirely.
- **Hydration timing**: an SSR page captured before hydration differs from one captured after (attributes React/Vue add, portals not yet mounted). Give `readyScript` a real signal; a diff whose paths are all inside a portal container is the first thing to suspect.
- **Portaled overlays** (menus, dialogs, tooltips) render at the end of `body`; both builds must open them in the same step order or the node paths shift.
- **`outline-width`** 1px vs 3px with `outline-style: none` is the UA focus default, ignored automatically.
- **Sub-pixel heights** (`19.9922px` vs `20px`) mean a folded `calc()` line-height — a real bug, see `MAPPING.md`.
- **Serialised custom properties** differ in whitespace between minifiers; normalised automatically.
