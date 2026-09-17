# Stack adapters

Pick the adapter that matches the repository. Each names where content, tokens and the page live, the commands, and the pitfalls that produced review failures before. Look up anything else in the repository itself: package scripts, config files, the existing variant closest to your register.

## Fenchem landing (TanStack Start + StyleX)

| Item | Location |
|---|---|
| content module | `apps/web/src/components/landing/landing-content.ts` (stats, industries, pillars, ingredients, processSteps, certificationDetails, regions, company, navLinks, createInquiryHref) |
| tokens | `packages/ui/src/tokens.stylex.ts` (`colors`, `radii`, `typography`, `breakpoints`); brand and landing rules in `docs/brand/` |
| motion primitives | `apps/web/src/components/prototype/motion.tsx` (`Reveal` with `sx`), `motion-constants.ts` (`EASE`, `STAGGER`), `use-reduced-motion.ts` |
| map outline | `apps/web/src/components/prototype/world-map-path.ts` (2000×1001 plane; x = (lon+180)/360·2000, y = (90−lat)/180·1001) |
| page file | `apps/web/src/components/prototype/variant-<key>.tsx` exporting `Variant<Key>` |
| registry | `apps/web/src/components/prototype/variants.ts` (`key`, lazy `Component`, `name`); route test in `apps/web/src/routes/-index.test.tsx` |
| dev URL | `http://localhost:3001/?variant=<key>` (`bun run dev:bare` in `apps/web`) |
| checks | `bun oxlint <file>`, `bun oxfmt --write <file>`, `cd apps/web && bunx tsc --noEmit -p tsconfig.json`, `bun run test` |
| capture | `PW=/abs/path/node_modules/@playwright/test CHANNEL=chrome URL=... node scripts/capture.mjs` |

Pitfalls, each a past review failure:

- Three responsive tiers on one property are emitted in hash order. Write the middle tier as `"@media (min-width: 768px) and (max-width: 1023.98px)"`.
- StyleX has no descendant selectors. A parent hover that restyles a child uses React state set by `onPointerEnter`/`onFocus` on the parent.
- `ul`/`ol` grids need `margin: 0, padding: 0, listStyle: "none"` in the style object.
- Grid auto-placement is sparse: a later item with an earlier column drops to the next row. Order the DOM by column.
- Dynamic values (tick positions, chart coordinates) go in the `style` prop; static values go in `stylex.create`.
- `Reveal` wraps the content in a `div`; pass layout styles through `sx`.
- Every `m.*` element sits under `<LazyMotion features={domAnimation} strict>`.

## Astro (Tailwind v4 or plain CSS)

| Item | Location |
|---|---|
| content module | `src/content/` collections or `src/data/*.ts`; read the existing landing's imports |
| tokens | `src/styles/global.css` `@theme` block (Tailwind v4) or `:root` custom properties |
| page file | `src/pages/<key>.astro` composed from `src/components/landing/*.astro` |
| dev URL | `http://localhost:4321/<key>` (`astro dev`) |
| checks | `astro check`, the repo's lint script |
| motion | CSS transitions plus an `IntersectionObserver` for reveals; `@media (prefers-reduced-motion: reduce)` disables them |

Pitfalls:

- Scoped styles in `.astro` files do not reach child components; put shared rules in `global.css` under `@layer components`.
- Tailwind v4 only emits classes present in source; a class built from a variable string never renders. Write full class names.
- `client:*` directives are only for islands that need JavaScript; the reveal observer can live in one small inline `<script>`.

## Any other stack

Find these four things before building and write them into the brief: the content source, the token source, the page entry, the dev URL. Then apply the law and the presentation table with the stack's own idioms.
