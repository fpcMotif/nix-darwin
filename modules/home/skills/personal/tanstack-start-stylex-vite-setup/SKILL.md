---
name: tanstack-start-stylex-vite-setup
description: "TanStack Start SSR + StyleX Vite setup recipes: dev virtual CSS injection in __root.tsx, defineConsts for breakpoints, and per-property conditional rules."
---

# TanStack Start + StyleX Vite Setup and Gotchas

When configuring `@stylexjs/unplugin` with TanStack Start (SSR) in Vite monorepos:

## 1. Dev Mode Virtual CSS Injection in `__root.tsx`
TanStack Start SSR does not use Vite's standard `transformIndexHtml` pipeline. In dev mode, `@stylexjs/unplugin` serves dynamic compiled CSS at `/virtual:stylex.css`.
You MUST explicitly link this virtual stylesheet in `__root.tsx`:

```tsx
export const Route = createRootRouteWithContext<RouterAppContext>()({
  head: () => ({
    links: [
      {
        rel: "stylesheet",
        href: appCss,
      },
      ...(import.meta.env.DEV
        ? [
            {
              rel: "stylesheet",
              href: "/virtual:stylex.css",
            },
          ]
        : []),
    ],
  }),
  // ...
});
```

Without this link, the application will render completely unstyled markup with raw StyleX hashes in dev mode.

---

## 2. `.stylex.ts` Token Modules: `defineConsts` vs `defineVars`
In `.stylex.ts` files, StyleX treats plain object exports as CSS variables (`var(--...)`) by default.
For media query strings (breakpoints, motion queries), you MUST wrap them in `stylex.defineConsts({ ... })`:

```ts
import * as stylex from "@stylexjs/stylex";

export const breakpoints = stylex.defineConsts({
  sm: "@media (min-width: 640px)",
  md: "@media (min-width: 768px)",
  lg: "@media (min-width: 1024px)",
  xl: "@media (min-width: 1280px)",
  motionReduce: "@media (prefers-reduced-motion: reduce)",
});
```

If not wrapped in `defineConsts`, StyleX generates invalid selectors like `var(--x123){ ... }` instead of `@media (min-width: 768px){ ... }`.

---

## 3. StyleX Media Queries & Conditionals Rule
StyleX requires media queries and conditionals to be defined **per property**, never as nested rule blocks:

```ts
// CORRECT
const styles = stylex.create({
  container: {
    paddingInline: {
      default: "1rem",
      [breakpoints.md]: "2rem",
    },
  },
});

// WRONG (Throws 'Invalid pseudo or at-rule')
const styles = stylex.create({
  container: {
    paddingInline: "1rem",
    [breakpoints.md]: {
      paddingInline: "2rem",
    },
  },
});
```
When a property has no default base value, use `default: null` (never `default: undefined`).
