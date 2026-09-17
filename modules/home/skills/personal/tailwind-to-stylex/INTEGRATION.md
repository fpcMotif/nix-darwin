# StyleX wiring per stack (StyleX 0.19.x)

Reference for the intake and infrastructure steps. Pick the bundler row, then the framework row; write both into the spec.

## Bundlers

| Project | Wiring |
|---|---|
| Vite, Rollup, webpack, Rspack, esbuild, Bun, Rolldown, Farm | one package, `@stylexjs/unplugin`, one call from its subpath export: `stylex.vite({...})`, `.rollup()`, `.webpack()`, `.rspack()`, `.esbuild()`, `.bun()`, `.rolldown()`, `.farm()`. webpack/Rspack pair it with `babel-loader` + `MiniCssExtractPlugin` / `CssExtractRspackPlugin`; for esbuild pass `metafile: true` so the plugin finds CSS outputs without scanning `outdir`. |
| Next.js (≥ 16.0.3, webpack or Turbopack — the official guide's floor) | `@stylexjs/babel-plugin` in `babel.config.js` + `@stylexjs/postcss-plugin` (with `autoprefixer`) in `postcss.config.js`; a bare `@stylex;` directive in the root CSS (`app/globals.css`) is replaced by the atomic CSS at build. `@stylexjs/nextjs-plugin` is deprecated on npm (last 0.11.1, 2025) — do not use it. |
| Storybook, custom pipelines, anything the unplugin cannot hook | the same babel-plugin + postcss-plugin route with an explicit `include` glob. |
| Multi-build tools (WXT, Electron-Vite, monorepos with several Vite builds) | one plugin instance per build that renders UI; the plugin's rule store is process-wide, so an instance attached to every build leaks CSS into sibling outputs (a WXT content-script CSS grew StyleX rules). Attach through the tool's per-build hook (WXT: `hooks['vite:build:extendConfig']`). |

Do not install `@stylexjs/webpack-plugin`, `@stylexjs/esbuild-plugin` (npm-deprecated) or `@stylexjs/vite-plugin` (never existed). `@stylexjs/rollup-plugin` still publishes but the unplugin export is the maintained path.

Options that matter for parity (babel-plugin options pass through every adapter):

- `unstable_moduleResolution: { type: 'commonJS', rootDir }` — required as soon as `defineVars`/`defineMarker` are used. Token files must be named `*.stylex.{js,mjs,cjs,ts,tsx,jsx}` (or `themeFileExtension`) and export named values.
- `aliases: { '@/*': [path.join(root, 'src', '*')] }` — the babel plugin does not read tsconfig paths; without this a `*.stylex.ts` import through an alias fails to resolve.
- `lightningcssOptions: { targets: browserslistToTargets(browserslist('<the project floor>')) }` — pin to the real browser floor; default lowering (e.g. `light-dark()`) can change emitted declarations. lightningcss folds `calc()` in declarations (see `MAPPING.md`).
- `runtimeInjection: false` (default) in production — parity rests on static CSS; runtime injection reorders rules at hydration.
- `cssInjectionTarget: (fileName) => boolean` (unplugin) — which emitted CSS asset receives the atomic rules (default `index.css`/`style.css`/first `.css`); point it at the asset every migrated page links.
- `useCSSLayers: true` — emits `@layer` priority blocks instead of `:not(#\#)` specificity bumps; changes how project global CSS must be ordered (see `MAPPING.md` § Structural rules).
- `importSources` — only if the codebase imports StyleX under another name.
- `devMode` (Vite only): `'full'` (default) | `'css-only'` | `'off'`; `devPersistToDisk` only when the dev setup runs separate Node processes per environment (client/SSR in one process already share the in-memory store).

Dev mode: the Vite adapter serves `/virtual:stylex.css` and `virtual:stylex:runtime` and injects both into HTML it serves through `transformIndexHtml`. A page whose HTML Vite does not serve (extension pages under WXT, some Electron/SSR templates, another origin) gets nothing injected: link the stylesheet from `new URL('/virtual:stylex.css', import.meta.url)` under `import.meta.env.DEV` and refresh it on the `stylex:css-update` HMR event. Verify dev after the build is green; it is a separate code path.

SSR: each output (client, server) aggregates its own StyleX CSS; link the client stylesheet once at the document root. Nothing in a component may branch on `window`/`matchMedia`/storage at render time or server and client class lists diverge.

## Frameworks

| Framework | Call | Notes |
|---|---|---|
| React | `{...stylex.props(a, b)}` → `{ className?, style? }` (keys omitted when empty) | Host elements also accept the compile-time shorthand `sx={styles.x}` (rename via `sxPropName`); custom components need a real prop. |
| Preact | `stylex.props()` | Preact accepts `className` and `class`; keep one convention per codebase. |
| Solid, Vue, Svelte, Qwik | `stylex.attrs(...)` → `{ class?, style? }` strings | Solid/Qwik JSX bind `class` (Qwik prefers `class`, warns on `className` in dev, and community reports say production builds ignore it). Vue SFC: `v-bind="stylex.attrs(styles.x)"`, with `stylex.create` in a plain `<script>` block or a sibling `.ts` module — `<script setup>` compiles into `setup()`, where the babel plugin throws "only allowed at the root of a program" (facebook/stylex discussion #154); run the StyleX plugin after `@vitejs/plugin-vue` (no `enforce: 'pre'`, do not exclude `.vue` ids — issue #1562). Svelte: spread `{...stylex.attrs(styles.x)}` and keep `stylex.create` in `<script module>` (the official SvelteKit example). |
| Astro, Lit, vanilla | `stylex.attrs()` strings via spread / `setAttribute` | No upstream example; smoke-test computed styles before trusting parity. Dynamic (function) styles need a hydrated island. |

Rules that hold everywhere: `stylex.create` at module top level (inside a plain function it compiles but loses static inlining; inside a framework-generated function such as Vue's `setup()` it fails); values are literals, local constants, or imports from `*.stylex.*` files — no spreads, no computed strings; dynamic values are arrow-function styles that become CSS variables set through the `style` attribute.

## Component API

A reusable component takes external styles through one prop, applied last: `stylex.props(styles.base, variant && styles.variant, sx)`. Type it as `StyleXStyles` for leaves, `StyleXStylesWithout<{ position?: unknown; display?: unknown; margin*/padding*/width/height… }>` when layout must stay sealed, `StaticStyles` when dynamic styles must be rejected. Arrays flatten: `stylex.props([a, b])` equals `stylex.props(a, b)`.

Projects that lint with ESLint (spec §2) add `@stylexjs/eslint-plugin` (its recommended set: `valid-styles`, `valid-shorthands`, `sort-keys`, `enforce-extension`, `no-unused`, `no-legacy-contextual-styles`, `no-lookahead-selectors`, `no-nonstandard-styles`) to the gate; it is a separate package. Other linters (oxlint, Biome) have no StyleX rules — the spec records "no automated StyleX lint coverage" and the review step carries that weight.
