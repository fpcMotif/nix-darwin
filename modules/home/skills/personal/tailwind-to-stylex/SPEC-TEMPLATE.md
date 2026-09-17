# Migration spec — <project>

> ⚠️ **TARGET IS THE CURRENT ACTIVE PROJECT**: Always inspect the project in the active working directory or worktree. Any examples under `examples/` are non-normative sample illustrations from past migrations — NEVER search for, reference, or confuse them with your target project.

Filled by the intake step (`workflows/intake.js` or by manual codebase analysis); a non-normative sample illustration: [`examples/SPEC-example-extension.md`](examples/SPEC-example-extension.md). Every convert / review agent reads this file first; it is the single place where the project's stack, conventions, and overrides live. Keep `MAPPING.md` general — project facts go here.
## 1. Stack

| Fact | Value |
|---|---|
| UI framework | <React 19 / Preact / Solid / Vue 3 / Svelte 5 / Qwik / Astro islands> |
| StyleX call | <`stylex.props()` for React/Preact JSX (className+style objects) · `stylex.attrs()` for Solid/Vue/Svelte/Qwik/vanilla (class+style strings)> |
| Class prop today | <`className` / `class` / `:class` / `class:` directive> |
| Style-forwarding prop after migration | <name, e.g. `sx`; type `StyleXStyles`; applied last> |
| Bundler / meta-framework | <Vite / Next.js 16 (webpack or Turbopack) / webpack / Rspack / Rollup / esbuild / Bun / WXT / Electron-Vite …> |
| StyleX wiring (from INTEGRATION.md) | <`@stylexjs/unplugin` `.vite()` … / babel-plugin + postcss-plugin (`@stylex` directive in <file>)> |
| Build that renders the UI | <which build/output the plugin must attach to; sibling builds that must stay byte-identical> |
| Rendering | <CSR SPA / SSR + hydration / SSG / islands> |
| Browser floor | <browserslist / `chrome >= 120` …> — lightningcss targets |
| Tailwind major | <3.x / 4.x> — ground truth: `<path to compiled CSS>` |
| Dark mode | <`media` (prefers-color-scheme) / `class` on `<selector>` with `<value>` / `attribute <name>=<value>` / none> → StyleX: <`@media` keys in defineVars / `createTheme` applied at the root> |
| Component library | <shadcn on Base UI / shadcn on Radix / Radix / Headless UI v2 / React Aria / Ark / Kobalte / Bits / Reka / none> |
| State attribute vocabulary | <e.g. `data-state=open|closed`, `data-checked`, `data-disabled`, `data-highlighted`, `aria-invalid`, `data-slot=<part>`> |
| Class-merge / variant helpers | <tailwind-merge via `cn()` + cva / tailwind-variants / clsx only / none> |
| Animation helpers | <tw-animate-css / tailwindcss-animate / none> |
| Icons / leaf components | <shared icon component and its size/inert conventions, or none> |

## 2. Gate (exact commands)

| Step | Command |
|---|---|
| format | <`bunx oxfmt --write` / `pnpm prettier --write` / …> |
| lint | <…> |
| typecheck | <… or n/a> |
| unit tests | <… — and how tests assert styling today (class-string greps, snapshots)> |
| build | <…> |
| full gate | <the one command CI runs> |

## 3. Global CSS that outranked utilities

Rules outside the utilities layer that won against utility classes on the same element. Each becomes a value written directly on every affected element; the global rule is then deleted.

| Selector | Declarations | Elements affected | Value to restate |
|---|---|---|---|
| <`[data-slot='button']`> | <`transition-duration: 160ms; transition-timing-function: var(--ease)`> | <every Button, ToggleGroup item …> | <…> |

## 4. Merge-helper conflict rules in force

<Which helper resolves conflicting utilities and where: `cn(base, className)` at every component call site; `cva` variant strings vs base; call-site overrides that strip a base utility (later `text-*` strips `leading-*`; `rounded-[…]` replaces `rounded-lg`; `w-*` replaces `w-full`).> If the project has no helper: "none — later class wins only by stylesheet order".

## 5. Parent → child rules and where they went

| Utility | Parent gets | Global rule (specificity) |
|---|---|---|
| <`divide-y`> | <`data-divide=""`> | <`:where([data-divide] > :not(:last-child)) { border-top/bottom… }` (0,0,0)> |
| <`*:py-4`> | <`data-rows="4"`> | <`[data-rows='4'][data-rows]:not(#\#)×4 > * { padding-block: 1rem }`> |

## 6. Descendant markers

| Tailwind | Marker (`defineMarker`) on host | Read on descendant |
|---|---|---|
| <`[&_svg]:size-4`> | <`iconSize4`> | <`stylex.when.ancestor(':is(*)', iconSize4)` → width/height 1rem> |

## 7. Dropped rules

Utilities no call site can reach (explain each): <`group-*` with no `group` ancestor, `in-data-[…]`, `[[data-variant=legend]+&]` …>. Every drop is also commented at its site.

## 8. Tokens

<`defineVars` file path; the original custom-property names kept verbatim (`'--primary'`), dark values via `@media` or via a theme; derived values (`--radius-md: calc(var(--radius) - 2px)`); text-size line-height fractions routed through variables because lightningcss folds `calc()` in declarations.>

## 9. Component API

<How components accept outside styles after migration (prop name, type, position in `stylex.props`/`attrs` argument list), what happens to `asChild`/`render` props, and how tests will assert styling (e.g. import the style object and check `stylex.props(styles.x).className` contains the class).>

## 10. Parity hosts and scenarios

<Which `parity.ts` host captures this app (`--serve dist` / `--url` dev server or `next start` / `--cdp` Electron/extension), hydration hook (`readyScript`), `settledSelectors`, `darkMode`, the scenario list (every route, every interactive state worth arming, narrow viewports for each viewport breakpoint, and steps that resize the container ancestor across each `@container` threshold), and states the harness cannot reach (listed for the review step).>

## 11. File groups

| Group | Files | Tests | Notes |
|---|---|---|---|
| A | <shared primitives> | <…> | <global overrides that apply here> |
| B | <views> | <…> | <…> |
