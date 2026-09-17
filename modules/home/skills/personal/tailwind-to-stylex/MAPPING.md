# Tailwind → StyleX mapping

Reference for the convert and review steps. Every value comes from the project's **ground truth** (its compiled Tailwind CSS); this file says how to write what you find there and where the two cascades differ. Tables give Tailwind v4 defaults with the v3 delta beside them — the ground truth decides, never the version label alone.

## Authoring shape

```ts
import * as stylex from '@stylexjs/stylex'
import { tokens } from '@/theme/tokens.stylex'

const HOVER = '@media (hover: hover)'   // v4 only — v3 hover is bare ':hover'
const DARK = '@media (prefers-color-scheme: dark)'

const styles = stylex.create({
  row: {
    display: 'flex',
    color: { default: tokens['--foreground'], [HOVER]: { ':hover': tokens['--primary'] } },
    opacity: { default: null, ':disabled': 0.5 },
  },
})
// React/Preact: <div {...stylex.props(styles.row, active && styles.active, sx)} />
// Solid/Vue/Svelte/Qwik: stylex.attrs(...) — see INTEGRATION.md
```

- Later arguments win **per property**: a later `backgroundColor` replaces the earlier one's every variant, including its `:hover`. A later `{ default: null, ':first-child': x }` wipes an earlier plain value — merge variants into one object. Under the default `styleResolution: 'property-specificity'` a longhand beats a same-area shorthand whatever the order (`paddingTop` applied first still wins over a later `padding`); write the longhands the caller must be able to override.
- Condition keys that compile: `':hover'`, `':focus-visible'`, `':active'`, `':disabled'`, `':first-child'`, `':last-child'`, `':nth-last-child(2)'`, `':not(:last-child)'`, `':active:not([aria-haspopup])'`, `':is(a):hover'`, `':has([data-icon="inline-end"])'`, `':has(> [data-slot="field-content"])'`, `'[data-checked]'`, `'[data-state="open"]'`, `'[aria-invalid="true"]'`, `'[data-open][data-side="bottom"]'`, `'@media (hover: hover)'`, `'@media (prefers-color-scheme: dark)'`, `'@media (width >= 40rem)'`, `'@media (forced-colors: active)'`, `'@container name (width >= 28rem)'`. `default` is required beside any condition; `null` means no declaration.
- Pseudo-elements are top-level keys: `'::after': { content: '""', … }`, `'::placeholder'`, `'::file-selector-button'`.
- `!important` compiles but escalates the whole property; avoid it.
- Keep existing inline styles (`style=`, `:style`) as they are.

## Effective declarations

Write what the element **ends up with**, not a transliteration of each class:

- **Utility order is stylesheet order.** Two utilities setting one property resolve by their position in the compiled CSS, whatever the order in the class string (`leading-*` beats the line-height of `text-*`; `pl-*` beats `px-*`).
- **Global rules that beat utilities.** Any project rule that outranked utilities (v4: unlayered rules beat `@layer utilities`; v3: later or more specific selectors) — e.g. `[data-slot='button'] { transition-duration: 160ms }` — has no layer to hide behind in StyleX. Write the winning value on every affected element and delete the global rule. The spec (§3) lists them.
- **Merge helpers at call sites and inside variant definitions** (`tailwind-merge`'s `cn(base, className)`, `cva`, `tailwind-variants`): a later utility removes earlier ones in its conflict group before the class string exists. Model the component base as resolved declarations and let the caller's style prop override the same properties. Traps: a later text-size utility (`text-xs`, `text-[13px]`) removes the base `text-*` **and any earlier `leading-*`** — set `fontSize` plus the new size's own line-height, or `lineHeight: null` for an arbitrary size; the size variant's `rounded-[…]` replaces `rounded-lg`; `w-*` replaces `w-full`/`w-fit`; `min-w-*` replaces `min-w-0`. Projects without a merge helper: later class wins only by stylesheet order.
- **Dark defaults shadow light variants.** In StyleX a `[DARK]: { default: x }` outranks sibling `':focus-visible'` / `'[aria-expanded="true"]'` keys, whereas Tailwind's `focus-visible:border-ring` (0,2,0) beat `dark:border-input` (0,1,0). Restate those variants inside the dark block.
- **Hover**: v4 wraps every `hover:` in `@media (hover: hover)` → `{ default, [HOVER]: { ':hover': … } }` (also inside dark blocks); v3 emits a bare `:hover` → `{ default, ':hover': … }`. The ground truth shows which.
- **Descendant rules** (`[&_svg]:size-4`, `[&>svg]:pointer-events-none`) become a `defineMarker` on the host and `stylex.when.ancestor(':is(*)', marker)` conditions on the descendant's own styles; an explicit size on the descendant replaces them (the `svg:not([class*='size-'])` opt-out).
- **`group-*` / `peer-*` / `in-*`** are ancestor- or sibling-scoped Tailwind selectors, not library attributes: `group-data-[state=open]:rotate-180` → marker on the group element, `stylex.when.ancestor('[data-state="open"]', marker)` on the child; `peer-checked:` → `when.siblingBefore`. Drop the rule if no call site has the ancestor.
- **Dead rules** (no call site can reach them: `group-*` with no group, `in-data-[slot=…]` with no such ancestor, `[[data-variant=legend]+&]`, a `*:[span]:last:` rule whose child is a `div`) are dropped with a `// dropped: <utility> — <why>` comment at the site.
- **`duration-*` / `ease-*` without a `transition-*` utility** still set `transition-duration`/`-timing-function` (property defaults to `all`): keep them.
- **lightningcss folds `calc()` in declarations** (`calc(1.25 / 0.875)` → `1.42857`, a hair shorter in layout) but not inside custom properties: route v4's `--text-*--line-height` fractions through `defineVars` and reference the token. v3 line-heights are rem literals; write them directly.

## Structural rules (parent → child)

`divide-*`, `space-*`, `*:py-4`, `*:w-full`, `*:data-[slot=…]:flex-auto`, `[&>a]:underline` have no StyleX form that leaves the children untouched (`when.ancestor` styles only elements that apply a style themselves, and these children are arbitrary). Move them to the global stylesheet keyed on `data-*` attributes the parent carries or gains (`data-divide`, `data-rows="4"`), reproducing the original cascade outcome:

- v4 `:where(…)` rules stay at zero specificity: `:where([data-divide] > :not(:last-child)) { … }`. v3 `space-*`/`divide-*` use `> :not([hidden]) ~ :not([hidden])` with physical properties; keep that shape.
- Rules that must beat the children's own StyleX declarations (`*:py-4` beat `py-2` on a child? check the ground truth — usually the child's utility wins and `first:`/`last:` variants beat `*:` rules) need a specificity StyleX cannot reach. StyleX sorts declarations into priority buckets (shorthand 1000 < `padding-block` 2000 < logical longhands 3000 < physical longhands 4000, plus pseudo-class/at-rule offsets) and, in the default mode, appends `:not(#\#)` once per bucket rank **present in that build's bundle** — the count for a property is bundle-relative, so read it from the compiled CSS (`grep -c ':not(#\\#)'` on the rule) rather than assuming. A doubled attribute plus one more bump than the highest plain-declaration rank — e.g. `[data-rows='4'][data-rows]:not(#\#):not(#\#):not(#\#):not(#\#) > *` when longhands carry three — beats every plain declaration and still loses to pseudo-class variants, which sit in higher buckets. Re-check after every build that adds new variant kinds.
- Deterministic alternative: `useCSSLayers: { after: ['app'] }` (unplugin/postcss/rollup option) makes StyleX emit `@layer priorityN` blocks and declare the project's `app` layer after them; structural rules in `@layer app` then win by layer order, no bumps, no counting. Unlayered CSS beats every layer; `!important` reverses layer order (a losing layer's `!important` wins) — keep `!important` out of both sides.
- A value that flows down (not a rule that must win): set a `defineVars` token conditionally on the parent and read it in the child's own styles — the technique StyleX's descendant-styles recipe documents, no marker, any depth.

## Dark mode

| Strategy in the project | Tokens | Harness |
|---|---|---|
| media (`prefers-color-scheme`) — v4 default, v3 `darkMode: 'media'` | `defineVars` values `{ default, '@media (prefers-color-scheme: dark)': … }`; emitted `:root` block is byte-equivalent | `schemes: ["light","dark"]` |
| class / attribute (`.dark`, `[data-theme=dark]`, next-themes) — v3 `darkMode: 'class'`, v4 `@custom-variant dark (&:where(.dark, .dark *))` | `defineVars` holds light; `stylex.createTheme(tokens, darkValues)` applied on the root element when the app is dark (its class replaces `.dark`; `class` is ignored by compare). `dark:` utilities on elements become `tokens` reads or a theme-scoped value, not a `[DARK]` key | `darkMode: { mode: 'class' … }` + `resetScript` seeding the theme key |
| none | no dark keys | `schemes: ["light"]` |

## Component library attributes

Attribute keys mirror what the library sets on the element the utility targeted. Check the installed major; the vocabulary changes across majors.

| Library | State attributes | Hidden native input for `toggle()` |
|---|---|---|
| Radix (React), Reka UI (Vue) | valued `data-state` per component: `open|closed`, `checked|unchecked|indeterminate`, `active|inactive`, `on|off`; `data-disabled`, `data-highlighted`, `data-placeholder`, `data-side`, `data-align`, `data-orientation` | Switch/Checkbox only inside a `<form>` or with a `form` prop |
| Base UI (`@base-ui/react` 1.x) | paired presence attributes: `data-open`/`data-closed`, `data-checked`/`data-unchecked`, `data-disabled`, `data-highlighted`, `data-selected`, `data-pressed`, `data-valid`/`data-invalid`, `data-side`, `data-orientation`; transient `data-starting-style`/`data-ending-style` | Switch always |
| shadcn/ui (on Radix or Base UI) | the primitive's attributes plus `data-slot="<part>"` on every part (part identity, not state) | as the primitive |
| Headless UI v2 | `data-open`, `data-checked`, `data-active`, `data-focus`, `data-hover`, `data-disabled`, `data-selected` (v1's combined `data-headlessui-state` is still emitted beside them); transition-only `data-closed`, `data-enter`, `data-leave`, `data-transition` | Checkbox only with `name` |
| React Aria Components | render props 1:1 as `data-hovered`, `data-pressed`, `data-focused`, `data-focus-visible`, `data-selected`, `data-disabled`, `data-invalid`, `data-open`, … | always (visually hidden) |
| Ark UI | compound `data-scope` + `data-part` + `data-state` | per component |
| Kobalte (Solid) | presence attributes: `data-checked`, `data-highlighted`, `data-expanded`, `data-selected`, `data-disabled`, `data-invalid`… | per component |
| Bits UI (Svelte) | valued `data-state` (`checked|unchecked`, `open|closed`) plus `data-disabled`; its docs also list `data-checked` but the runtime does not emit it — read the rendered DOM | Switch only with `name` |

Transient animation attributes (`data-starting-style`, `data-enter`) exist for one frame or one transition: capture them only through the same animation longhands the original had, never as a resting-state key.

## Value tables

Spacing `N × 0.25rem` (both majors; v4 writes `calc(var(--spacing) * N)`, the computed value is the same): 0.5→`0.125rem` 1→`0.25rem` 1.5→`0.375rem` 2→`0.5rem` 2.5→`0.625rem` 3→`0.75rem` 3.5→`0.875rem` 4→`1rem` 5→`1.25rem` 6→`1.5rem` 8→`2rem` 10→`2.5rem` 11→`2.75rem` 12→`3rem`; `px`→`1px`; `screen`→`100vh`; `max-w-2xl`→`42rem`. Write the property Tailwind emitted: `px-*`→`paddingInline`, `py-*`→`paddingBlock`, `-mx-1`→`marginInline: '-0.25rem'`, `inset-y-0`→`insetBlock: 0`, `size-4`→`width`+`height`, `truncate`→`overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap'`, `flex-1`→`flex: 1`, `w-fit`→`'fit-content'`, `line-clamp-1`→`WebkitLineClamp: 1, WebkitBoxOrient: 'vertical', display: '-webkit-box', overflow: 'hidden'`.

**Type** — v4: `text-xs` `0.75rem`/`calc(1 / 0.75)` · `text-sm` `0.875rem`/`calc(1.25 / 0.875)` · `text-base` `1rem`/`calc(1.5 / 1)` · `text-xl` `1.25rem`/`calc(1.75 / 1.25)` · `text-2xl` `1.5rem`/`calc(2 / 1.5)`. v3: fixed rem line-heights (`text-xs` `1rem`, `text-sm` `1.25rem`, `text-base` `1.5rem`, `text-xl` `1.75rem`, `text-2xl` `2rem`). Arbitrary `text-[13px]` sets font-size only · `leading-none` 1, `-tight` 1.25, `-snug` 1.375, `-normal` 1.5, `-relaxed` 1.625 · `font-medium` 500, `-semibold` 600 · `tracking-tight` `-0.025em`, `-wide` `0.025em` · `tabular-nums`→`fontVariantNumeric` · `text-balance`/`text-pretty`→`textWrap`.

**Radius** — v4 references theme variables (`var(--radius-lg)`; shadcn: `var(--radius)`, `-md` `calc(var(--radius) - 2px)`, `-sm` `calc(var(--radius) - 4px)`, `-xl` `calc(var(--radius) + 4px)`), v3 writes literals (`rounded-lg` `0.5rem`, `-md` `0.375rem`, `-xl` `0.75rem`). v4 shifted the size names one step (`v3 rounded` = `v4 rounded-sm`, `v3 rounded-sm 0.125rem` ≠ `v4 rounded-sm 0.25rem`; same for `shadow`, `blur`) — find a v3 value by its literal, never by the v4 row name. `rounded-full`: v4 `3.40282e38px` (`calc(infinity * 1px)` folded), v3 `9999px`.

**Borders**: `border` → `borderStyle: 'solid', borderWidth: '1px'`; sides likewise (`border-t` → `borderTopStyle` + `borderTopWidth`). v4 preflight gives every element `border: 0 solid` and the colour falls to `currentcolor` unless the project sets `--border`/`border-color` in its base layer; v3 preflight sets `border-color: #e5e7eb` (or the configured default) and `cursor: pointer` on buttons — carry whichever the ground truth has into the global preflight block.

**Colours** — v4 opacity modifiers: `color-mix(in oklab, var(--x) N%, transparent)` (write the literal; keep the `@supports` srgb fallback only if the browser floor predates oklab `color-mix`). v3: `rgb(R G B / 0.5)` literal for `/50`, and `rgb(R G B / var(--tw-bg-opacity, 1))` plus the variable for plain colours — write the resolved literal.

**Rings / shadows** — v4 composes five layers; write the whole effective list so computed values match: `focus-visible:ring-3 focus-visible:ring-ring/50` → `':focus-visible': '0 0 #0000, 0 0 #0000, 0 0 #0000, 0 0 0 3px color-mix(in oklab, var(--ring) 50%, transparent), 0 0 #0000'`; `shadow-md ring-1 ring-foreground/10` → `'0 0 #0000, 0 0 #0000, 0 0 #0000, 0 0 0 1px color-mix(in oklab, var(--foreground) 10%, transparent), 0 4px 6px -1px #0000001a, 0 2px 4px -2px #0000001a'`; `ring-0` → `'… 0 0 0 0px currentcolor, 0 0 #0000'`. v3 composes three layers (`ring-offset-shadow, ring-shadow, shadow`), bare `ring` is 3px `rgb(59 130 246 / 0.5)`, `shadow-md` = `0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)`. Count the layers in the ground truth. A variant that only sets `ring-<color>` is visible only with the width-setting `focus-visible:ring-N` — model it as the compound key `':focus-visible[aria-invalid="true"]'`.

**Transitions** — v4 `transition-colors` → `'color, background-color, border-color, outline-color, text-decoration-color, fill, stroke, --tw-gradient-from, --tw-gradient-via, --tw-gradient-to'`; v3 → `'color, background-color, border-color, text-decoration-color, fill, stroke'`. `transition-transform` v4 → `'transform, translate, scale, rotate'`, v3 → `'transform'`. `transition-[a,b]` verbatim. Default timing `cubic-bezier(0.4, 0, 0.2, 1)`, duration `0.15s`; `duration-100` `0.1s`, `duration-[180ms]` `0.18s`.

**Transforms** — v4 individual properties: `scale-90` → `scale: '90% 90%'`, `active:scale-[0.97]` → `scale: { default: null, ':active': 0.97 }`, `translate-y-1` → `translate: '0 0.25rem'`, `translate-x-[calc(100%-2px)]` → `'calc(100% - 2px) 0'`; `skew-*` and `rotate-x/y/z` stay on `transform`. v3 composes one `transform: translate(x, y) rotate(r) skewX(a) skewY(b) scaleX(sx) scaleY(sy)` string from `--tw-*` variables — write the resolved shorthand with the defaults filled in (`translate(0, 0) rotate(0) skewX(0) skewY(0) scaleX(1) scaleY(1)` around the changed function).

**Animations** (tw-animate-css / tailwindcss-animate): keyframes in the same file, six longhands. `animate-in fade-in slide-in-from-top-1` → `stylex.keyframes({ '0%': { opacity: 0, transform: 'translate3d(0, calc(1 * 0.25rem * -1), 0) scale3d(1, 1, 1) rotate(0)', filter: 'blur(0)' } })` with `animationDuration` = the element's `duration-*`, `animationTimingFunction` = its `ease-*` or `'ease'`, delay `'0s'`, iteration `1`, direction `'normal'`, fill `'none'`. `zoom-in-95` → `scale3d(0.95, 0.95, 0.95)`; `-from-top-2` → y `calc(2 * 0.25rem * -1)`; exit (`animate-out fade-out-0 zoom-out-95`) → `{ to: { opacity: 0, transform: 'translate3d(0, 0, 0) scale3d(0.95, 0.95, 0.95) rotate(0)', filter: 'blur(0)' } }`. Gate every longhand under the same `[data-open]`/`[data-closed]` (or `[data-state="open"]`) keys with `default: null` so a settled element carries no animation.

**Misc**: `sr-only` → `{ position: 'absolute', width: '1px', height: '1px', padding: 0, margin: '-1px', overflow: 'hidden', clipPath: 'inset(50%)', whiteSpace: 'nowrap', borderWidth: 0 }` (v3: `clip: rect(0, 0, 0, 0)` instead of `clipPath`) · `outline-none` → `outlineStyle: 'none'` · v4 `outline-hidden` → `outlineStyle: { default: 'none', '@media (forced-colors: active)': 'solid' }` + width `2px`, colour `#0000`, offset `2px` under forced colours · `after:absolute after:-inset-x-1` → `'::after': { content: '""', position: 'absolute', insetInline: '-0.25rem' }` · `@container/name` → `containerName` + `containerType: 'inline-size'` (v3 needs the `@tailwindcss/container-queries` plugin; without it the classes were dead) · `!` modifier: prefix in v3 (`!flex`), suffix in v4 (`flex!`, the prefix still accepted as deprecated) — a source-lookup detail only.
