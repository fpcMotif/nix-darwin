---
name: stylex-tanstack-start-vite-recipes
description: "TanStack Start SSR + StyleX Vite setup recipes: dev virtual CSS injection in __root.tsx, defineConsts for breakpoints, and per-property conditional rules."
---

# StyleX + TanStack Start Vite Integration Recipes

Key patterns and pitfalls when using StyleX with TanStack Start (SSR) and Vite:

## 1. Dev Virtual Stylesheet Injection in TanStack Start

### Problem
TanStack Start uses custom SSR document rendering in `__root.tsx` and does not call Vite's `transformIndexHtml`. `@stylexjs/unplugin`'s automatic dev stylesheet injection hook is bypassed, causing the browser in dev mode to receive generated class names (`xh25fyl`) without any matching CSS.

### Solution
In `__root.tsx`, explicitly add the virtual StyleX stylesheet link during development:

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

---

## 2. Media Queries & Breakpoints in `.stylex.ts`

### Rule
StyleX treats **every plain object export** from a `.stylex.ts` file as CSS variables (`defineVars`) unless wrapped in `stylex.defineConsts`. Exporting raw string objects causes media query strings to compile into broken selectors like `var(--x123){...}` instead of `@media (min-width: 768px){...}`.

### Solution
Wrap breakpoint maps with `stylex.defineConsts`:

```ts
import * as stylex from "@stylexjs/stylex";

export const breakpoints = stylex.defineConsts({
  sm: "@media (min-width: 640px)",
  md: "@media (min-width: 768px)",
  lg: "@media (min-width: 1024px)",
  xl: "@media (min-width: 1280px)",
  "2xl": "@media (min-width: 1536px)",
  motionReduce: "@media (prefers-reduced-motion: reduce)",
  motionOk: "@media (prefers-reduced-motion: no-preference)",
  dark: "@media (prefers-color-scheme: dark)",
});
```

---

## 3. Style Object Rule Flattening (No Nested `@media` Blocks)

### Rule
StyleX does not support top-level nested `@media` rule blocks inside a `stylex.create` definition:

```ts
// ❌ INVALID IN STYLEX:
const styles = stylex.create({
  card: {
    padding: "1rem",
    [breakpoints.md]: { padding: "2rem" },
  }
});

// ✅ VALID IN STYLEX (Per-property conditional):
const styles = stylex.create({
  card: {
    padding: {
      default: "1rem",
      [breakpoints.md]: "2rem",
    },
  }
});
```

If a property has no base value and only applies under a media condition, use `default: null`:

```ts
display: {
  default: null,
  [breakpoints.md]: "flex",
}
```

---

## 4. Compiler Production Optimizations in `vite.config.ts`

```ts
import stylex from "@stylexjs/unplugin";

export default defineConfig({
  plugins: [
    stylex.vite({
      useCSSLayers: true,
      runtimeInjection: false,
      enableInlinedConditionalMerge: true,
      treeshakeCompensation: true,
      enableDebugClassNames: false,
      enableDevClassNames: false,
      unstable_moduleResolution: {
        type: "commonJS",
        rootDir: fileURLToPath(new URL("../..", import.meta.url)),
      },
    }),
  ],
});
```
