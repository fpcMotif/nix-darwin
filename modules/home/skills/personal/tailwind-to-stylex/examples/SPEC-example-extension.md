# Reference Example Spec — Web Extension with Preact & Base UI

> ⚠️ **NON-NORMATIVE REFERENCE SPEC**: This is an illustrative example of a completed spec for a WXT + Preact + Base UI extension. It is NOT the project you are currently migrating. Do NOT search for this repo or commit on your machine. Always inspect the active workspace.

This example illustrates how a filled `SPEC.md` looks for an extension project. Every convert / review agent reads the project's actual `SPEC.md` generated during step 0.
## 1. Stack

| Fact | Value |
|---|---|
| UI framework | Preact 10.29.x, rendered through `preact/compat` as a React shim so the vendored shadcn/ui files (authored for React) run unmodified; JSX via `jsxImportSource: 'preact'` (tsconfig.json). Two JSX conventions coexist: popup/options/shadcn code uses `className` (resolved through preact/compat); the separate overlay content-script UI uses Preact's native `class=` (that build is outside StyleX's scope — see "Build that renders the UI" below). |
| StyleX call | `stylex.props()` — React/Preact JSX, returns `{ className, style }`. Confirmed as the pattern already adopted throughout (`src/components/ui/button.tsx`, `icons.tsx`, `confirm-strip.tsx`, every options panel, both popup files). |
| Class prop today | `className` (popup/options/shadcn surface). The overlay content-script surface uses `class=` but carries zero Tailwind utility classes and is out of scope for this migration (see §11 "out of scope"). |
| Style-forwarding prop after migration | `sx`, typed `StyleXStyles` (from `@stylexjs/stylex`), applied **last** in the `stylex.props(...)` argument list — e.g. `button.tsx`: `stylex.props(styles.base, variantStyles[variant], sizeStyles[size], svgHost, svgMarkerBySize[size], sx)`; `icons.tsx`'s `IconProps` omits `className`/`class` and adds `sx?: StyleXStyles`. This is already the established, consistent convention across every converted file. |
| Bundler / meta-framework | WXT `^0.20.26` (`0.20.27` installed, patched via `patches/wxt@0.20.26.patch`) wrapping Vite, with `@preact/preset-vite ^2.10.5` for the Preact JSX transform. |
| StyleX wiring (from INTEGRATION.md) | Multi-build-tool row: **one plugin instance per build that renders UI**, attached through WXT's per-build hook. Package: `@stylexjs/unplugin`, imported from its Vite subpath — `import stylex from '@stylexjs/unplugin/vite'`, called as a factory `stylex({...})`. Wired in `wxt.config.ts` via `hooks['vite:build:extendConfig']` (production, gated on `entrypoints.some(e => HTML_ENTRYPOINT_TYPES.has(e.type))`) and `hooks['vite:devServer:extendConfig']` (dev, unconditional — WXT runs one dev server for the whole extension). `HTML_ENTRYPOINT_TYPES = new Set(['popup', 'options', 'unlisted-page'])`. Options actually set: `unstable_moduleResolution: { type: 'commonJS', rootDir: process.cwd() }`; `aliases: { '@/*': [path.join(process.cwd(), 'src', '*') ] }` (the babel plugin does not read tsconfig paths — INTEGRATION.md); `cssInjectionTarget: (fileName) => /(^\|\/)app-[^/]*\.css$/.test(fileName)` (targets the shared popup+options CSS asset, `assets/app-*.css`); `lightningcssOptions: { targets: browserslistToTargets(browserslist('chrome >= 120')) }`; `devMode: 'css-only'` (dev pages the WXT dev server doesn't serve through Vite's own `transformIndexHtml` link the stylesheet manually — see `src/theme/stylex-dev.ts`'s `linkStylexDevStylesheet()`, called from `popup/main.tsx` and `options/main.tsx` under `import.meta.env.DEV`, refreshing on the `stylex:css-update` HMR event). |
| Build that renders the UI | The HTML-entrypoint group (popup + options + the offscreen `unlisted-page`, though offscreen itself renders no Preact UI). Sibling builds that must stay byte-identical / StyleX-free: the MV3 background service worker (`background.ts`) and the content-script group (`inject.content.ts`, `overlay.content/*` — the overlay has its own Preact UI but its own plain-CSS stylesheet, untouched by this migration). This is exactly the leak WXT's multi-build wiring guards against (INTEGRATION.md: "a WXT content-script CSS grew StyleX rules"). `backend/` (Convex) is a wholly separate, non-Vite build outside this migration's scope entirely. |
| Rendering | CSR only, no SSR/SSG/islands. `popup/main.tsx` and `options/main.tsx` both call `render(<App/>, root)` directly into `#app` on load (`root.replaceChildren()` first). Chrome MV3 extension, not a server-rendered app. |
| Browser floor | No `.browserslistrc` / `package.json` browserslist field anywhere in the frontend. Pinned imperatively: Vite `build.target: 'chrome120'` (unchanged pre/post migration) plus, new in the StyleX wiring, `lightningcssOptions.targets: browserslistToTargets(browserslist('chrome >= 120'))`. Pre-migration Tailwind v4's own lightningcss had no explicit browserslist call — only the `chrome120` Vite target constrained it. |
| Tailwind major | v4 (CSS-first config, no `tailwind.config.{js,ts}` anywhere in the repo). Resolved version `4.3.2` (bun.lock). Ground truth: `src/app.css` on `main` (`git show main:src/app.css`), independently reproduced via a fresh `git worktree add … main && bun install && bun run build`, byte-identical (md5 `24183465ad3214f41dd5fbea284b009e`) to the compiled `assets/app-*.css`. |
| Dark mode | `media` (`prefers-color-scheme`) — v4's `@custom-variant dark { @media (prefers-color-scheme: dark) { @slot; } }` in `src/app.css` (pre-migration), chosen deliberately because "the popup follows the OS theme" rather than a toggled `.dark` class. No class/attribute strategy anywhere. → StyleX: `defineVars` values as `{ default, '@media (prefers-color-scheme: dark)': … }` inside `src/theme/tokens.stylex.ts` (already written this way for every color/shadow token that varies — see §8). Parity harness: `schemes` default (`darkMode.mode` not overridden in `scripts/parity.config.json`, so it defaults to `'media'`). |
| Component library | shadcn/ui vendored on **Base UI** (`@base-ui/react ^1.6.0`), **not** Radix — a prior Radix→Base UI migration predates this Tailwind→StyleX one (confirmed by header comments in every `src/components/ui/*.tsx` file contrasting old Radix behavior with current Base UI behavior). No `components.json` exists on `main` or in the working tree. 11 vendored files: `badge.tsx`, `button.tsx`, `field.tsx`, `input.tsx`, `label.tsx`, `progress.tsx`, `select.tsx`, `separator.tsx`, `switch.tsx`, `toggle-group.tsx`, `toggle.tsx`. |
| State attribute vocabulary | Base UI paired-presence attributes: `data-checked`/`data-unchecked` (Switch), `data-pressed` (Toggle/ToggleGroupItem), `data-open`/`data-closed` + `data-side` + `data-highlighted` + `data-placeholder` (Select), `data-orientation` (Field, Separator), `data-disabled`. shadcn's own `data-slot="<part>"` on every vendored part (part identity, not state) — e.g. `data-slot="button"`, `data-slot="switch"`, `data-slot="field-label"`. Two custom, hand-rolled attributes not from any library: `data-variant` / `data-size` (Badge/Button/Select/Switch, set directly by the component) and `data-horizontal`/`data-vertical`/`data-spacing` (ToggleGroup, set by hand in `toggle-group.tsx` — real and alive, unlike Field's broken lookalike, see §3/§7). Also targeted: `aria-invalid`, `aria-expanded` (Button outline/secondary/ghost, driven by caller state), `aria-pressed` (Toggle, paired with `data-pressed`). Post-migration: two project-authored structural attributes, `data-xmd-divide` / `data-xmd-rows="N"` (§5), and `data-xmd-popup="loading" \| "ready"` on the popup root (replacing the old `.xmd-popup`/`.xmd-popup--loading` classes). |
| Class-merge / variant helpers | Pre-migration: `cn()` re-exported wholesale from the third-party npm package `cn` (`^0.2.4`, **not** a hand-rolled `clsx`+`tailwind-merge` wrapper — `src/lib/utils.ts` was a single re-export line, now deleted along with `src/lib/utils.test.ts`; `src/lib` no longer exists in the working tree). `class-variance-authority (cva)` used for exactly 4 variant maps, all in `src/components/ui/`: `badgeVariants`, `buttonVariants`, `toggleVariants` (shared by Toggle and ToggleGroupItem), `fieldVariants`. No `tailwind-variants`; `clsx` was a listed dependency but never imported directly anywhere in `src`. Post-migration: no merge helper — each component's `stylex.create()` base + `variantStyles[variant]` + `sizeStyles[size]` + marker(s) + caller `sx` are passed as separate `stylex.props()` arguments; StyleX's own later-argument-wins-per-property rule replaces `cn`/`cva`'s string-conflict resolution (see §4). |
| Animation helpers | `tw-animate-css ^1.4.0` (Tailwind v4's replacement for `tailwindcss-animate`; imported globally in `app.css`, line 2). 7 pre-migration call sites: the shadcn Select popup's `data-state`-gated open/close transition, plus 6 plain enter-only reveal panels (popup `App.tsx` ×4, `capture-quick-actions.tsx` ×1, `confirm-strip.tsx` ×1) that all hardcode a custom `duration-[220ms]`/`duration-[180ms]` + `ease-[var(--xmd-ease)]` override on top of tw-animate-css's default timing. Post-migration: each site now defines its own `stylex.keyframes(...)` (confirmed: `select.tsx` — 5 keyframes gated under `[data-open]`/`[data-closed]`; `confirm-strip.tsx` — `fadeIn`; `popup/App.tsx` — `enterFadeSlideTop1`, reused 4×; `capture-quick-actions.tsx` — its own `enterFadeSlideTop1` copy) with `animationDuration`/`animationTimingFunction` set to the same literal values the Tailwind classes compiled to. |
| Icons / leaf components | `src/components/icons.tsx` — 5 hand-authored inline Preact SVG icons (`EraserIcon`, `LayersIcon`, `CheckIcon`, `ChevronDownIcon`, `ChevronUpIcon`), deliberately not `lucide-react`, sharing one `base` attrs object (18×18 default via SVG width/height, overridden per call site). Pre-migration sizing was a `className` `size-*` utility (CSS wins over the HTML attribute); post-migration sizing is the `sx` prop (`IconProps` explicitly omits `className`/`class`). Ancestor-scoped default sizing (call sites that render an icon with no explicit size, relying on the vendored component's `[&_svg:not([class*='size-'])]:size-4`-style selector) is now a `defineMarker` + `stylex.when.ancestor(...)` pair — see §6. |

## 2. Gate (exact commands)

| Step | Command |
|---|---|
| format | `bun run fmt` → `oxfmt --write src` (check-only: `bun run fmt:check` → `oxfmt --check src`) |
| lint | `bun run lint` → `oxlint` (CI-strict: `bun run lint:ci` → `oxlint --deny-warnings`); separately `bun run lint:boundaries` → `depcruise src` enforces the package-boundary rule in AGENTS.md |
| typecheck | `bun run typecheck` → `wxt prepare && tsgo --noEmit` — uses `tsgo` (`@typescript/native-preview ^7.0.0-dev…`), **not** `tsc`; `tsconfig.json` extends WXT-generated `.wxt/tsconfig.json` for the `@/*`/`~/*`/`@@/*`/`~~/*` path aliases |
| unit tests | `bun run test` → `varlock run -- vitest run` (varlock loads/validates env vars first; environment `happy-dom`). **How tests assert styling**: source-string greps, not DOM-render assertions — `readFileSync('src/…/Foo.tsx', 'utf8')` then `expect(source).toContain(/.not.toContain(/.toMatch(...)`, a documented "house idiom." No `@testing-library/preact`, no `toHaveClass`/`getByRole` anywhere in the suite. 4 files' Tailwind-class-string assertions were already rewritten as StyleX-object assertions in the working tree: `src/components/confirm-strip.test.ts`, `src/entrypoints/options/panels/saving.test.ts`, `src/entrypoints/popup/App.test.ts`, `src/entrypoints/popup/popup-layout.test.ts` (e.g. `toContain('pointer-events-none')` → `toContain("pointerEvents: 'none'")`). Coverage (`bun run test:coverage` → `vitest run --coverage`) is scoped to `src/core/**`, `src/lib/**` (now an empty/dead glob — `src/lib` was deleted), `src/packages/**` at 100% statement/branch/function/line — UI code (`src/components/**`, `src/entrypoints/**`) is explicitly excluded from the coverage gate by design. |
| build | `bun run build` → `varlock run -- wxt build` (WXT/Vite build; `build.target: 'chrome120'`, `rollupOptions.treeshake.moduleSideEffects: false`) |
| full gate | `bun run check` → `oxfmt --check src && oxlint && varlock audit src backend && wxt prepare && tsgo --noEmit && depcruise src && vitest run` (documented verbatim in `AGENTS.md`; unchanged by the migration). No CI pipeline exists in the repo (no `.github/workflows` or any CI YAML on any branch) — `bun run check` is the de-facto gate, run manually or by an agent. `bun run test:backend` / `test:all` cover the separate Convex backend gate and are **not** part of `check`. |

## 3. Global CSS that outranked utilities

All rows below are unlayered (or unlayered + `!important`) rules read from `main`'s `src/app.css` /
`src/entrypoints/options/style.css`. Per the CSS Cascade Layers spec, an unlayered normal
declaration always outranks a declaration inside a named layer (Tailwind's utilities live in
`@layer utilities`) regardless of selector specificity or source order — importance **reverses**
this (an unlayered `!important` sits at the *lowest* priority of all `!important` declarations).

| Selector | Declarations | Elements affected | Value to restate |
|---|---|---|---|
| `html, body, #app` | `width:380px; min-width:380px; margin:0; background:var(--xmd-bg)` | Every popup/options document root | Kept as plain (non-StyleX) global CSS in the post-migration `app.css` §2 ("Root element properties") — no utility ever targeted these elements directly, so no restatement needed on a component. Confirmed unchanged post-migration (still present verbatim, height pins removed per a comment: "the popup renders its content's height"). |
| `.xmd-popup` / `.xmd-popup--loading` | `width:380px; max-width:100%; background:var(--xmd-bg); color:var(--xmd-ink); font:13px/1.35 system-ui,…` | Popup root div (`popup/App.tsx`) | Already folded into `styles.popup` / `styles.loading` in `popup/App.tsx` (`stylex.create`), no longer a class in `app.css` at all. Loading state now keyed on `data-xmd-popup="loading"` (not a class) — confirmed by `scripts/frameshift-visual-qa.ts` and `scripts/parity.config.json`'s `settledSelectors`, which check both `.xmd-popup--loading` (legacy) and `[data-xmd-popup="loading"]` (current). |
| `[data-slot='button']` | `transition-duration:160ms; transition-timing-function:var(--xmd-ease)` | Every shadcn Button instance (`data-slot="button"` set unconditionally by `button.tsx`, and hand-copied onto raw `<button>` elements in `confirm-strip.tsx`) | `transitionDuration: '0.16s'; transitionTimingFunction: 'var(--xmd-ease)'` — confirmed already restated directly in `button.tsx`'s `styles.base` (with an explicit comment citing "spec §3"), and in `confirm-strip.tsx` (comment: "`data-slot=\"button\"` override baked in: transitionDuration '0.16s' …"). |
| `[data-slot='switch'], [data-slot='switch-thumb']` | `transition-duration:150ms; transition-timing-function:var(--xmd-ease)` | Switch root + thumb | Confirmed already restated in `switch.tsx`'s `styles.root` (`transitionDuration: '0.15s'`, comment citing "spec §3"). |
| `.bg-primary.text-primary-foreground` (inside `@media (prefers-color-scheme: dark)`) | `--color-primary-foreground: oklch(0.145 0.006 var(--xmd-hue-neutral))` | **Scoped deliberately** to elements carrying both `bg-primary` AND `text-primary-foreground`: Button default variant, Badge default variant, popup Download CTA (`App.tsx`). The original comment is explicit: `--primary-foreground` must stay white for Switch's checked-thumb fill (`dark:data-checked:bg-primary-foreground`), so the AA-contrast fix could not be applied to the token globally — only to the three filled-control call sites that pair it as *text on a filled `--primary` background*. | **False positive, resolved by the baseline capture.** The compiled ground truth still contains the rule, but the dark popup capture shows the filled button computed `color: oklch(1 0 0)` on `main` too — the ` inline` mapping inlined `var(--primary-foreground)` into the utility, so the override never took effect. The migration preserved the rendered white; parity is 0. Lesson: a rule that sets a custom property is live only if the compiled utility reads that property — check the ground truth and the baseline capture before calling an override "live". |
| `:root, html, body, #app` (`options/style.css`) | `width:auto !important; min-width:0 !important; height:auto !important; min-height:100vh !important; max-height:none !important; overflow:visible !important;` | Options page (relaxes the popup's 380×600 box for the full-tab options view) | Not a utility conflict (no Tailwind utility on these elements) — kept verbatim as plain CSS post-migration (`options/style.css` unchanged; confirmed byte-identical). Per the importance-reversal rule this file's own comment ("`!important` keeps the override robust regardless of injection order") is not quite right — as unlayered `!important` it is the *lowest*-priority `!important`, though no conflicting important utility exists on these elements today. |
| `.xmd-options-root` (`options/style.css`) | `background: var(--xmd-bg)` | Options App root div, which also carried the Tailwind utility `bg-background` for the same property | This was a confirmed **live** override pre-migration (unlayered beats `@layer utilities` regardless of value; visually inert only because `--xmd-bg === --background`). Post-migration: the options root's background is set once via `stylex.create`, no competing rule — resolved by construction. |
| `[&>svg]:size-3!` (Badge, trailing-bang `!important` utility) | `size-3` on any `<svg>` child of Badge | **Dead** on `main` — no Badge call site (`options/App.tsx`, `release.tsx`, `history.tsx`) ever renders an `<svg>` child; the only other `<Badge>`-looking element (`overlay.content/index.tsx`'s `BadgeButton`) is an unrelated component. | Modeled as the `badgeSvg` marker in `src/theme/markers.stylex.ts`, consumed by `icons.tsx` — comment explicitly notes "the `!important` is not carried; an explicit `sx` size on the icon replaces these rules wholesale anyway." Confirmed present and correctly reasoned about. |
| `* , *::before, *::after` (`@media (prefers-reduced-motion: reduce)`) | `animation-duration:0.01ms !important; animation-iteration-count:1 !important; transition-duration:0.01ms !important; scroll-behavior:auto !important` | Every element | Kept verbatim as plain global CSS in post-migration `app.css` §4 ("Reduced motion") — a universal `!important` reset like this cannot be expressed per-component in StyleX and was correctly left as a global stylesheet rule rather than migrated. |
| `@layer base { * { @apply border-border outline-ring/50 } }` plus the rest of Tailwind's preflight | box-sizing, margin/padding resets, `border-color: var(--border)` default, etc. | Every element | Kept **byte-for-byte** in post-migration `app.css` §1, deliberately still wrapped in `@layer base` — the comment explains why: "every StyleX rule (unlayered) wins over it, exactly as utilities beat the base layer before." This is the one rule in this table that was *correctly* left inside a layer rather than restated per-component, because it is a true baseline reset, not a utility-vs-custom-rule conflict. |

## 4. Merge-helper conflict rules in force

**Pre-migration**: `cn(base, className)` at every vendored component's call site (`badge.tsx`,
`button.tsx`, `field.tsx`, `input.tsx`, `label.tsx`, `progress.tsx`, `select.tsx`, `separator.tsx`,
`switch.tsx`, `toggle-group.tsx`, `toggle.tsx`), backed by the third-party `cn` package (confirmed
last-wins Tailwind-conflict behavior via the deleted `src/lib/utils.test.ts`, e.g.
`cn('px-2','px-4')` → `'px-4'`). `cva` variant strings (`badgeVariants`, `buttonVariants`,
`toggleVariants`, `fieldVariants`) were passed through the same `cn()` as the base, so a
caller-supplied `className` always wins last. Outside `src/components/ui/`, five leaf/page files
(`confirm-strip.tsx`, `options/App.tsx`, `options/panels/sync.tsx`, `popup/App.tsx`,
`popup/capture-quick-actions.tsx`) called `cn(base, conditionalTernary)` directly (2–3 branches),
never threading a `className` prop from a parent — these are leaves, not reusable primitives.

**Post-migration**: no merge helper. Effective declarations are modeled directly in each
component's `stylex.create()` call, split into `base` / `variantStyles[variant]` /
`sizeStyles[size]` objects; a caller's `sx` prop is the last argument to `stylex.props(...)`, so it
wins per-property over every earlier argument — replacing `cn`'s string-concatenation-then-resolve
behavior with StyleX's native later-argument-wins-per-property rule (MAPPING.md "Authoring shape").
The traps MAPPING.md calls out (`text-*` stripping `leading-*`, `rounded-[…]` replacing
`rounded-lg`, `w-*` replacing `w-full`) are the same traps to re-check at every one of these call
sites when reading the pre-migration `cva`/`cn` output as ground truth for what a variant "ends up
with."

## 5. Parent → child rules and where they went

| Utility | Parent gets | Global rule (specificity) |
|---|---|---|
| `divide-y divide-border` (`ui.tsx` `Section`/`FieldGroup`, `archive.tsx`'s `<ol>`, `saving.tsx`'s aria2 group, `release.tsx`'s sub-group) | `data-xmd-divide=""` | `:where([data-xmd-divide] > :not(:last-child)) { border-top-style: solid; border-bottom-style: solid; border-top-width: 0; border-bottom-width: 1px; border-color: var(--border); }` — kept at zero specificity via `:where(...)`, matching the original Tailwind `divide-y` (also zero-specificity), so a child's own border styles still win. |
| `*:py-4` (`ui.tsx`'s `Section` → `FieldGroup`) | `data-xmd-rows="4"` (alongside `data-xmd-divide=""`) | `[data-xmd-rows='4'][data-xmd-rows]:not(#\#):not(#\#):not(#\#):not(#\#) > * { padding-block: 1rem; }` — doubled attribute selector plus four `:not(#\#)` bumps (StyleX's default, non-layer specificity-escalation scheme), one rank higher than the highest plain-declaration bucket present in this bundle, confirmed by reading the compiled rule directly rather than assumed. |
| `*:py-3 first:*:pt-0` (`saving.tsx`'s aria2 group, `release.tsx`'s sub-group) | `data-xmd-rows="3"` (`data-xmd-divide=""` alongside) | `[data-xmd-rows='3'][data-xmd-rows]:not(#\#):not(#\#):not(#\#):not(#\#) > * { padding-block: 0.75rem; }`. The `first:*:pt-0` half is **dropped** at both call sites — confirmed by an explicit `// dropped: first:*:pt-0 — this div is never itself a :first-child…` comment in both `saving.tsx` and `release.tsx` (the wrapping div this rule targeted is never itself a first child at either call site). |
| `*:w-full` (`field.tsx`, Field vertical orientation) | Field already carries `data-slot="field"` + `data-orientation="vertical"` (no new attribute needed — reuses existing part/state attributes) | `[data-slot='field'][data-orientation='vertical']:not(#\#):not(#\#):not(#\#):not(#\#) > * { width: 100%; }` |
| `*:data-[slot=field-label]:flex-auto` (`field.tsx`, Field horizontal orientation) | Same — reuses `data-slot="field"` + `data-orientation="horizontal"` | `[data-slot='field'][data-orientation='horizontal']:not(#\#):not(#\#):not(#\#):not(#\#) > [data-slot='field-label'] { flex: auto; }` |
| `[&>a]:underline [&>a]:underline-offset-4 [&>a:hover]:text-primary` (`field.tsx`, FieldDescription) | Reuses `data-slot="field-description"` | `[data-slot='field-description']:not(#\#):not(#\#):not(#\#):not(#\#) > a { text-decoration-line: underline; text-underline-offset: 4px; }` plus a paired `:hover > a` rule for `color: var(--primary)`. |

All five rules live in post-migration `src/app.css` §3 ("Structural parent → child rules"), each
with an inline comment explaining the specificity bucket count and citing which original Tailwind
utility it reproduces. The file explicitly notes the count is bundle-relative ("StyleX … appends
`:not(#\#)` … one to four times … depending on the property … These rules therefore carry four
`:not(#\#)` plus a second attribute … that beats every plain StyleX declaration a child can carry,
while a StyleX `:first-child`/`:last-child` variant … still wins over them"). `useCSSLayers` is
**not** enabled in this project's `stylexPlugin()` config (§1) — the specificity-bump scheme above
is the one actually in force, not the deterministic `@layer` alternative MAPPING.md also documents.
`ignoreAttributes` in `scripts/parity.config.json` (`data-xmd-popup`, `data-xmd-divide`,
`data-xmd-rows`) confirms the parity harness already treats these as intentional, non-diagnostic
attributes rather than noise to flag.

## 6. Descendant markers

All markers live in `src/theme/markers.stylex.ts`, read back exclusively by
`src/components/icons.tsx` via `stylex.when.ancestor(':is(*)', marker)`. `svgHost` is applied via
`stylex.props()` on the ancestor alongside the size marker; `icons.tsx` declares `pointerEvents`,
`flexShrink`, and `width`/`height` all keyed on the same ancestor conditions, so an icon rendered
inside e.g. a `sm` Button is inert, non-shrinking, and 14px without the call site doing anything —
exactly what `[&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-N`
did before. An icon's own `sx` prop is the last `stylex.props()` argument at any call site that
needs an explicit size, so it replaces these ancestor-driven width/height wholesale — reproducing
the `svg:not([class*='size-'])` opt-out exactly.

| Tailwind | Marker (`defineMarker`) on host | Read on descendant |
|---|---|---|
| `[&_svg]:pointer-events-none [&_svg]:shrink-0` | `svgHost` — applied by Button, Toggle, SelectTrigger, SelectItem | `pointerEvents: { default: null, [stylex.when.ancestor(':is(*)', svgHost)]: 'none' }`; `flexShrink: { default: null, [stylex.when.ancestor(':is(*)', svgHost)]: 0 }` |
| `[&_svg:not([class*='size-'])]:size-3` | `svgSize3` — Button `xs`/`icon-xs` | `width`/`height`: `0.75rem` under `stylex.when.ancestor(':is(*)', svgSize3)` |
| `[&_svg:not([class*='size-'])]:size-3.5` | `svgSize35` — Button `sm`/`icon-sm`, Toggle `sm` | `0.875rem` under the matching ancestor condition |
| `[&_svg:not([class*='size-'])]:size-4` | `svgSize4` — Button `default`/`lg`/`icon`/`icon-lg`, Toggle, SelectTrigger, SelectItem, select scroll arrows | `1rem` under the matching ancestor condition |
| `[&>svg]:pointer-events-none [&>svg]:size-3!` (Badge) | `badgeSvg` | `pointerEvents: 'none'`, size `0.75rem` — the `!important` is explicitly **not** carried (comment: "an explicit `sx` size on the icon replaces these rules wholesale anyway"); currently dead in practice since no Badge call site renders an `<svg>` child (§3). |

## 7. Dropped rules

Every drop below is already commented at its site with `// dropped: <utility> — <why>` per
MAPPING.md's convention, confirmed present in the working tree.

| Utility | Site | Why dropped |
|---|---|---|
| `in-data-[slot=button-group]:rounded-lg` (`xs`, `sm`, `icon-xs`, `icon-sm`) | `button.tsx` | No `[data-slot="button-group"]` ancestor exists anywhere in the codebase — no `ButtonGroup` component was ever built. |
| `has-data-[icon=inline-end\|inline-start]:pr/pl-*` | `button.tsx`, `toggle.tsx`, `badge.tsx`, `toggle-group.tsx` (via `group-data-[spacing=0]/toggle-group:has-data-[icon=…]`) | No component or call site anywhere in `src` ever sets `data-icon="inline-end"`/`"inline-start"` on a child — vendored shadcn boilerplate for an icon-inline-with-label pattern this app never adopted. |
| `has-[>[data-slot=checkbox-group]]:gap-3`, `has-[>[data-slot=radio-group]]:gap-3` (FieldSet) | `field.tsx` | No `CheckboxGroup`/`RadioGroup` component exists in the repo; `FieldSet`/`FieldLegend` are exported but never imported by any consumer. |
| `*:data-[slot=field-group]:gap-4` | `field.tsx` | No call site nests a `FieldGroup` directly inside another `FieldGroup`. |
| `[&>.sr-only]:w-auto` (both Field orientations) | `field.tsx` | No call site renders a `.sr-only` element as a direct child of Field. |
| `has-[>[data-slot=field-content]]:[&>[role=checkbox],[role=radio]]:mt-px` | `field.tsx` | Compound has-+ descendant selector with no matching call site (no checkbox/radio role rendered inside FieldContent in this app). |
| `group-data-[disabled=true]/field:opacity-50` / `pointer-events-none` (FieldLabel, FieldTitle) | `field.tsx` (×2 sites) | Field never sets `data-disabled` on itself; none of its ~40 call sites spread a `disabled`/`data-disabled` prop onto `<Field>` — individual children (Switch/Input) get `disabled` directly, never reflected back onto the wrapping Field. |
| `has-data-checked:border-primary/30`, `has-data-checked:bg-primary/5`, … (FieldLabel) | `field.tsx` | No call site nests a checked descendant control directly inside FieldLabel. |
| `has-[>[data-slot=field]]:rounded-lg`, `has-[>[data-slot=field]]:border`, … (FieldLabel) | `field.tsx` | No call site nests a `<Field>` directly inside `<FieldLabel>`. |
| `group-has-data-horizontal/field:text-balance` (FieldDescription) | `field.tsx` | **Attribute-name mismatch, not just a missing ancestor**: Field only ever sets `data-orientation="horizontal"`, never a boolean `data-horizontal` attribute — the selector's expected attribute never exists on Field at all, in any orientation. (Contrast with ToggleGroup, which correctly emits real `data-horizontal`/`data-vertical` and whose equivalent variant is kept, not dropped — see §1's state-attribute row and §11 Group B.) |
| `[[data-variant=legend]+&]:-mt-1.5` (FieldDescription) | `field.tsx` | No call site renders a `FieldLegend` (with `data-variant="legend"`) immediately before a `FieldDescription` — `FieldLegend` itself is never imported anywhere. |
| `group-data-[variant=outline]/field-group:-mb-2` | `field.tsx` (FieldSeparator or similar) | `FieldGroup`'s `variant="outline"` is never used at any call site in this app. |
| `peer-disabled:cursor-not-allowed peer-disabled:opacity-50` | `label.tsx` (and thus every FieldLabel) | **Broken DOM relationship, not a missing ancestor**: `peer-*` requires the `.peer`-classed Switch to be a *preceding sibling* of Label in the DOM. At every Field+Switch call site (~29 found across `saving.tsx`, `capture.tsx`, `release.tsx`, `sync.tsx`, `history.tsx`, `popup/App.tsx`), Switch is a sibling of `FieldContent`, while FieldLabel is nested one level deeper *inside* FieldContent — never a sibling of Switch. The selector this compiles to can never match that tree shape. |
| `*:[span]:last:flex *:[span]:last:items-center *:[span]:last:gap-2` | `select.tsx` (SelectItem) | Confirmed dropped with an explicit comment; the targeted `<span>` structure isn't produced by this app's Select usage. |
| `first:*:pt-0` | `saving.tsx` (aria2 group), `release.tsx` (sub-group) | The wrapping div this rule targeted is never itself rendered as a `:first-child` at either call site — see §5. |

**Inert-but-harmless, not formally "dropped" rules** (no consumer references them, but they also
cause no incorrect behavior, so no comment/action was needed): `group/badge` (`badge.tsx`) and
`group/toggle` (`toggle.tsx`) named groups with zero `.../badge:` or `.../toggle:` consumers
anywhere in the repo.

## 8. Tokens

`src/theme/tokens.stylex.ts` — `stylex.defineVars({...})`, imported as `tokens` everywhere. Every
key keeps its **historical custom-property name verbatim** (`'--xmd-bg'`, `'--primary'`,
`'--radius'`, etc. — including the leading `--`), exactly as MAPPING.md's Dark-mode table
prescribes, so the emitted `:root` block is byte-equivalent to the pre-migration one. Structure:

- **Brand ramp** (`--xmd-bg`, `--xmd-surface`, `--xmd-surface-raised`, `--xmd-ink`, `--xmd-muted`,
  `--xmd-faint`, `--xmd-line`, `--xmd-line-strong`, `--xmd-accent`, `--xmd-accent-hover`,
  `--xmd-accent-soft`, `--xmd-success`, `--xmd-danger`, `--xmd-shadow-1`, `--xmd-shadow-2`) — each
  an object literal `{ default: <light oklch>, [DARK]: <dark oklch> }` where
  `DARK = '@media (prefers-color-scheme: dark)'`, values copied verbatim from `main`'s
  `src/app.css` `:root` block and its `@media (prefers-color-scheme: dark) { :root { … } }` block.
- **Concentric radii** (`--xmd-radius-1..4`: `12px`/`10px`/`8px`/`6px`) — plain string values, no
  dark variant (radii don't change per theme).
- **shadcn semantic bridge tokens** (`--background`, `--foreground`, `--card`, `--popover`,
  `--primary`, `--primary-foreground`, `--secondary`, `--muted`, `--accent`, `--destructive`,
  `--success`, `--border`, `--input`, `--ring`, `--chart-1..5`, `--sidebar*`) — mostly plain
  `'var(--xmd-*)'` aliases, so dark values flow through automatically once the brand ramp switches;
  a few (`--popover`, `--success`) get their own explicit `{ default, [DARK] }` object because they
  don't cleanly alias a single brand token. **`--primary-foreground` and
  `--sidebar-primary-foreground` are both plain `'oklch(1 0 0)'` with no `[DARK]` key** — this is
  the confirmed, unresolved gap flagged in §3 (the original dark-mode AA-contrast fix was scoped to
  three specific "filled + text" call sites via a compound class selector, not to the token itself,
  and that scoped fix has not yet been reproduced anywhere in the StyleX version).
- **Derived radius**: `--radius: '0.75rem'`, `--radius-md: 'calc(var(--radius) - 2px)'` (both a
  named token *and* referenced as a literal `calc(var(--radius) - 2px)` inline in `select.tsx:192`
  — both forms coexist). `--radius-sm`/`--radius-xl` (present in `main`'s `@theme inline` block) do
  **not** appear as tokens here — TBD: check whether any current call site still needs the v4
  `rounded-sm`/`rounded-xl` step (7 `rounded-sm` and 0 `rounded-xl` uses were found on `main`) or
  whether those sites were already re-expressed as literal `calc()`/pixel values inline.
- **Font stacks + line-height fractions**: `--font-sans`, `--font-mono`,
  `--default-font-family`, `--default-mono-font-family` (verbatim from Tailwind's theme layer), and
  `--text-{xs,sm,base,xl,2xl}--line-height` as `calc(N / M)` string values — routed through
  `defineVars` specifically because (MAPPING.md) "lightningcss folds `calc()` in declarations but
  not inside custom properties," so writing `lineHeight: tokens['--text-sm--line-height']`
  preserves the exact unfolded fraction the Tailwind build produced, rather than a
  lightningcss-folded literal that lays out a hair different.

`src/theme/markers.stylex.ts` — `stylex.defineMarker()` calls, one per descendant-marker family
(§6), each documented with the Tailwind selector and consuming components it replaces.

`src/theme/tokens.css` (plain CSS, unrelated to `tokens.stylex.ts`) still holds only the
cross-surface primitives shared with the overlay content-script's own stylesheet
(`--xmd-ease`, `--xmd-hue-neutral: 255`, `--xmd-hue-success: 160`), imported by both `app.css` and
`overlay.content/style.css` — untouched by this migration, as the overlay is out of its scope.

## 9. Component API

Already established, consistently, across every converted file (not a proposal — verified in
`button.tsx`, `badge.tsx`, `icons.tsx`, and every options panel):

- A reusable component takes external styles through one prop, **`sx`**, typed
  `StyleXStyles` (imported from `@stylexjs/stylex`), applied as the **last** argument to
  `stylex.props(...)` so it wins per-property over the component's own base/variant/size/marker
  styles: `stylex.props(styles.base, variantStyles[variant], sizeStyles[size], svgHost, svgMarkerBySize[size], sx)`.
- `stylex.props()`'s `{ className, style }` result is spread into the element's/`useRender`'s
  `props` object alongside `data-slot`, `data-variant`, `data-size`, and any other data attributes
  the component sets — e.g. `button.tsx`'s `Button` returns
  `useRender({ defaultTagName: 'button', render, props: { 'data-slot': 'button', 'data-variant': variant, 'data-size': size, className, style, ...props } })`.
- `asChild`/`render`: Base UI's `render` prop (via `@base-ui/react/use-render`'s `useRender()`) is
  preserved unchanged — `Button` and `Badge` both accept an optional `render?: React.ReactElement`
  passed straight through to `useRender`, exactly as before the migration (this predates the
  Tailwind→StyleX work; it's the same Base UI API the prior Radix→Base UI migration already
  adopted).
- Icons (`icons.tsx`) follow the same shape one level down: `IconProps` is
  `Omit<JSX.SVGAttributes<SVGSVGElement>, 'className' | 'class'> & { readonly sx?: StyleXStyles }` —
  `className`/`class` are explicitly removed from the prop surface so `sx` is the only way to size
  or style an icon from a call site.
- Vendored files stay `// @ts-nocheck` (unrelated to this migration — a pre-existing
  preact/compat + `exactOptionalPropertyTypes` incompatibility with Base UI's `{...props}` spread
  pattern, called out in every vendored file's header comment).
- **Tests will assert styling** the same way §2 describes: import/read the `stylex.create()` object
  literal's source text (or, per the 4 already-rewritten test files, slice a named style key like
  `contextStrip: {...}` out of the source and check for a specific computed-value string such as
  `"pointerEvents: 'none'"` or `"boxShadow: …"`) — never a rendered-DOM `toHaveClass` assertion.

## 10. Parity hosts and scenarios

**Host**: `scripts/parity.ts` (1192 lines, untracked/new), extension mode — **not** `--serve`/`--url`
(this is an MV3 extension with no ordinary dev-server URL to point at; see §1's "no configured
dev-server URL" unknown). Two entry paths:
- `--launch <unpacked-dir> [--port N]` — headless Chrome-for-Testing with `--load-extension`.
- `--cdp <port> [--ext-id <id>] [--reload]` — attaches to an already-running Chrome with the
  extension loaded (the same CDP-port-9222 pattern `scripts/frameshift-visual-qa.ts` already uses);
  `--reload` makes Chrome re-read the unpacked extension first.

Two unpacked builds already exist on disk as of this writing: `.output/chrome-mv3` (current
branch, StyleX) and `.output/parity-baseline` (pre-migration Tailwind v4.3.2 build of `main`,
confirmed via its bundled CSS banner) — i.e. both sides of the A/B comparison are already staged.

**Settle/hydration**: every page waits for `document.fonts.ready`, an optional `readyScript`
(none configured in `scripts/parity.config.json`), the absence of every selector in
`settledSelectors` (`.xmd-boot-fallback`, `.xmd-popup--loading`, `[data-xmd-popup="loading"]` — both
the legacy class and the current attribute are checked), and a DOM-quiet window (`quietMs`) before
any scripted `steps` run.

**Dark mode**: `darkMode` is not overridden in `scripts/parity.config.json`, so it defaults to
`'media'` — correct per §1 (this app has no class/attribute dark-mode strategy to emulate).

**State targets**: `button, a[href], input, [role="switch"], [role="option"], [data-slot="select-trigger"], [data-slot="toggle-group-item"], [data-slot="badge"]`.

**Ignore attributes**: `data-xmd-popup`, `data-xmd-divide`, `data-xmd-rows` — the three
project-authored structural/state attributes from §1/§5, explicitly excluded from diff noise.

**Scenario list** (21 entries in `scripts/parity.config.json`, viewport default 1200×900, popup
override 380×600):
- Popup: `popup_none` (no active tab), `popup_x_home`, `popup_x_home_release_open`,
  `popup_x_home_release_armed` (ConfirmStrip armed, clock frozen, blurred for the underline-timing
  snapshot), `popup_x_list` (bookmarks/likes context), `popup_x_list_typed_word` (typed-word gate
  mid-entry), `popup_x_list_precommit_armed` (clearOnSave toggle armed), `popup_instagram`,
  `popup_x_mode_aria2` (Preferences Mode = aria2).
- Options: one scenario per section (`saving`, `release`, `capture`, `sync`, `archive`, `history`,
  `about`) plus `options_saving_select_open` (Base UI Select portal open),
  `options_saving_aria2`, `options_release_armed`, `options_release_on`, `options_sync_enabled`
  (both cloud toggles on), `options_archive_erase_armed`, and two narrow-viewport (560×900) variants
  (`options_saving_narrow`, `options_release_narrow`) for the one `sm:` breakpoint in the app.

**States the harness cannot reach** (for the review step):
- The **dark-mode AA-contrast gap in §3/§8** — every scenario above captures only the default
  color scheme unless the harness is explicitly re-run per scheme; confirm whether
  `scripts/parity.ts compare` is invoked once per `scheme` or only in light mode, since this is
  exactly the kind of computed-style diff a light-mode-only run would miss entirely.
- Base UI Select's portaled content (renders outside `#app`) — not confirmed whether the `compare`
  step's DOM diff already walks portal nodes.
- `aria2Granted`/`convexGranted` tri-state permission gates — depend on
  `browser.permissions.contains` resolving truthily inside the headless/CDP host; unconfirmed
  whether these resolve deterministically or stay stuck at `null` (loading) in capture.
- The Cloud Sync/Upload OAuth window (`chrome.identity.launchWebAuthFlow`) — unreachable headless;
  captured only in its pre-connect "Connect" button state (`options_sync`), never the
  post-OAuth state.
- IndexedDB-backed Capture/Archive data (`xmd-capture` DB) — `parity.ts`'s storage
  snapshot/clear/restore covers `chrome.storage` areas only, not IndexedDB, so Archive/Capture
  scenarios render whatever (real or absent) archive data exists in the attached profile, not a
  seeded fixture.
- The overlay content-script's on-page UI (hover badges, launcher dock) — no Tailwind utilities to
  migrate there at all (§1), and no fixture/live-page strategy is wired into `parity.ts` for it; out
  of scope for this migration's parity pass entirely.

## 11. File groups

23 files contain Tailwind utility classes on `main` (verified: every `.tsx`/`.ts` file under
`src/components/` and `src/entrypoints/{options,popup}/` was checked for `className=`-shaped
strings, or — for `button.tsx`/`badge.tsx`, which use Base UI's `useRender` prop-object pattern
instead of a JSX `className=` attribute — for a `className: cn(...)` object property). All 23 are
already `git status`-modified in the working tree, and **none retains a Tailwind-utility-shaped
`className` string** post-migration (verified by grep for common utility tokens inside
`className="..."` literals — zero hits across all 23 files) — every group below is convert-complete;
what remains is the review pass this spec supports. The overlay content-script, background worker,
offscreen document, and all three HTML `index.html` files are out of scope (§1: no Tailwind
utilities in any of them — the two `index.html` files use small hand-authored inline `<style>`
blocks, not utility classes).

| Group | Files | Tests | Notes |
|---|---|---|---|
| A — shadcn/ui primitives, static | `src/components/ui/badge.tsx`, `button.tsx`, `input.tsx`, `label.tsx`, `separator.tsx` (5) | No dedicated test file for any of these; exercised indirectly by every panel/popup test that renders a Button/Badge/Input. | §3's `[data-slot='button']` transition rule and the `.bg-primary.text-primary-foreground` dark-mode gap both land here (button.tsx, badge.tsx). §6's `svgHost`/`svgSize3`/`svgSize35`/`svgSize4`/`badgeSvg` markers are declared/consumed by button.tsx and badge.tsx. §7's dead `in-data-[slot=button-group]` and `has-data-[icon=…]` rules (button.tsx, badge.tsx) and the broken `peer-disabled` rule (label.tsx) all live here — all three already carry `// dropped:` comments. Badge's dead `[&>svg]:size-3!` (§3/§6) is here too. |
| B — shadcn/ui primitives, stateful/composite | `src/components/ui/switch.tsx`, `toggle.tsx`, `toggle-group.tsx`, `progress.tsx`, `select.tsx`, `field.tsx` (6) | No dedicated test file for any; `toggleVariants` is shared between `toggle.tsx` and `toggle-group.tsx` (imported, not duplicated) — a review pass should confirm the StyleX version still shares one style object rather than two independent copies. | §3's `[data-slot='switch']`/`[data-slot='switch-thumb']` transition rule (switch.tsx). §5's Field structural rules (`*:w-full`, `*:data-[slot=field-label]:flex-auto`, FieldDescription's `[&>a]` rule) all live in field.tsx and reuse `data-slot`/`data-orientation`, no new attribute needed. §6's `tw-animate-css` → `stylex.keyframes` conversion for Select's open/close transition (5 keyframes, gated under `[data-open]`/`[data-closed]`) is the most complex single conversion in this group — confirm the exit-keyframe direction and duration (`0.1s`/`ease`) match the original `data-state`-gated Tailwind classes exactly. §7's largest cluster of dropped rules is field.tsx (10 distinct drops, including the attribute-name-mismatch `group-has-data-horizontal/field:text-balance` — contrast with toggle-group.tsx's real, kept `data-horizontal`/`data-vertical`/`data-spacing` attributes in the same group). |
| C — shared cross-surface leaf + options shell | `src/components/confirm-strip.tsx`, `src/entrypoints/options/ui.tsx`, `src/entrypoints/options/App.tsx` (3) | `src/components/confirm-strip.test.ts` (already rewritten — one of the 4 files in §2's list; source-grep now checks `"pointerEvents: 'none'"` instead of `pointer-events-none`). | confirm-strip.tsx hand-writes `data-slot="button"` on two raw `<button>` elements (not the `Button` component), so §3's `[data-slot='button']` transition override applies here too — confirmed already baked in (comment cites "spec §3"). confirm-strip.tsx also owns the `fadeIn` keyframe (§1 animation helpers) and the module-singleton `disarmCurrent` (only one ConfirmStrip armed at a time app-wide — not a styling concern but affects any parity scenario that arms more than one strip). ui.tsx's `Section`/`FieldGroup` is the *origin* of the `*:py-4` → `data-xmd-rows="4"` structural rule (§5) — every options panel using `<Section>` inherits it. options/App.tsx is the only file with the app's one `sm:` responsive breakpoint (§1) and hand-renders the sidebar nav + `aria-current` (styled via a JS ternary, not an `aria-current:` variant). |
| D — options panels, settings tier | `src/entrypoints/options/panels/saving.tsx`, `release.tsx`, `capture.tsx`, `sync.tsx` (4) | `src/entrypoints/options/panels/saving.test.ts` (already rewritten — one of the 4 in §2). No dedicated test files found for `release.tsx`, `capture.tsx`, `sync.tsx` themselves beyond structural/copy assertions (confirm before assuming none exist). | saving.tsx and release.tsx both own a `*:py-3 first:*:pt-0` structural rule (§5) — a **different** row-padding value (`data-xmd-rows="3"`) than ui.tsx's `data-xmd-rows="4"`; keep the two values distinct, don't collapse them. Both also have the `first:*:pt-0` half already confirmed dropped (§7). saving.tsx additionally renders the Base UI Select (Quick Grab modifier) from Group B and the `aria2Granted` tri-state permission gate (§10, parity-unreachable). capture.tsx and sync.tsx are the two call sites most likely to hit Group A/B's broken `peer-disabled` (§7) in practice, since they render Field+Switch pairs directly. sync.tsx polls every 2000ms and opens an out-of-band OAuth window (§10) — style-wise only the pre-connect "Connect" button state is capturable. |
| E — options panels, library/utility tier | `src/entrypoints/options/panels/archive.tsx`, `history.tsx`, `about.tsx` (3) | No dedicated test files identified for these three beyond what §2 already lists (none of the 4 rewritten files are in this group). | archive.tsx owns its own `divide-y divide-border` structural rule (`data-xmd-divide=""` on its `<ol>`, no `*:py-N` counterpart — confirm whether it needs one or intentionally has none) and reuses confirm-strip.tsx's typed-word ConfirmStrip pattern for "Erase archive" (Group C) — keep the two in sync if either changes. history.tsx's Badge usage (plain `{f.status}` text) is one of the confirmed call sites proving Group A's `[&>svg]:size-3!` dead-rule finding (no svg ever passed). about.tsx is the lightest file in the app (4 pre-migration `className=` occurrences) — good low-risk file to spot-check first if validating the review methodology. |
| F — popup views | `src/entrypoints/popup/App.tsx`, `capture-quick-actions.tsx` (2) | `src/entrypoints/popup/App.test.ts` and `src/entrypoints/popup/popup-layout.test.ts` (both already rewritten — 2 of the 4 in §2). | Highest-density file in the whole app (62 pre-migration `className=` occurrences in App.tsx). Owns: the `.xmd-popup`/`.xmd-popup--loading` → `styles.popup`/`styles.loading` + `data-xmd-popup` conversion (§3); the confirmed **live** `.bg-primary.text-primary-foreground` dark-mode gap (§3/§8) at its Download CTA button; `aria-expanded:` variants on Button (outline/secondary/ghost, §1); 4 independent copies of the `enterFadeSlideTop1` keyframe pattern in App.tsx plus a 5th, separately-declared copy in capture-quick-actions.tsx (all `duration-[220ms]`/`0.22s` + `var(--xmd-ease)`) — a review pass should decide whether these 5 near-identical keyframe declarations belong in one shared module instead of being redeclared per file. Also the app's only `LINK_SLOP`-style shared `cn()` constant (pre-migration) across 3 call sites — confirm its post-migration equivalent (if any) is similarly deduplicated rather than copy-pasted 3×. |

