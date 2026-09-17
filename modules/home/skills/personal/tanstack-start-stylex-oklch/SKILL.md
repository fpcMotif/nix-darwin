---
name: tanstack-start-stylex-oklch
description: "Scaffold or build TanStack Start + StyleX web applications with OKLCH design tokens, Base UI headless components, and type-aware Oxlint."
---

# TanStack Start + StyleX + OKLCH + Base UI Setup Procedure

Use this skill when scaffolding or converting a project to use TanStack Start / TanStack Router with StyleX (`@stylexjs/stylex`), Base UI (`@base-ui-components/react`), OKLCH color tokens, strict zero-div semantic HTML, and type-aware Oxlint.

## 1. Core Dependencies
```bash
bun add @tanstack/react-router @tanstack/react-query @stylexjs/stylex @base-ui-components/react clsx lucide-react three
bun add -D vite-plugin-stylex @stylexjs/babel-plugin @vitejs/plugin-react oxlint oxlint-tsgolint oxfmt typescript vite
```

## 2. StyleX Vite Configuration & CSS Layer Integration
In `vite.config.ts`:
```ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import stylex from "vite-plugin-stylex";

export default defineConfig({
  plugins: [
    react(),
    stylex({ useCSSLayers: true })
  ]
});
```

In `src/index.css`:
```css
@layer reset, stylex;

@layer reset {
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
}

@layer stylex {
  @stylex stylesheet;
}
```

## 3. OKLCH StyleX Design Tokens (`src/tokens.stylex.ts`)
```ts
import * as stylex from "@stylexjs/stylex";

export const colors = stylex.defineVars({
  primary: "oklch(0.270 0.085 253.521)",
  accent: "oklch(0.527 0.169 258.070)",
  cremeWhite: "oklch(0.982 0.003 84.559)",
  white: "oklch(1.000 0.000 89.876)",
  imageOutline: "oklch(0 0 0 / 0.1)"
});
```

## 4. Base UI Integration with Semantic Tags & StyleX
Base UI components (`@base-ui-components/react/dialog`, `accordion`, `menu`) are 100% unstyled and support custom element rendering via the `render` prop:
```tsx
import { Dialog } from "@base-ui-components/react/dialog";
import * as stylex from "@stylexjs/stylex";

<Dialog.Root open={isOpen} onOpenChange={setIsOpen}>
  <Dialog.Portal>
    <Dialog.Backdrop render={<aside {...stylex.props(styles.backdrop)} />} />
    <Dialog.Popup render={<dialog open {...stylex.props(styles.modal)} />}>
      <Dialog.Title render={<h2 {...stylex.props(styles.title)}>Modal Title</h2>} />
    </Dialog.Popup>
  </Dialog.Portal>
</Dialog.Root>
```

## 5. Type-Aware Oxlint Configuration (`.oxlintrc.json`)
```json
{
  "$schema": "./node_modules/oxlint/configuration_schema.json",
  "plugins": ["react", "typescript", "jsx-a11y", "unicorn"],
  "rules": {
    "react/rules-of-hooks": "error",
    "react/exhaustive-deps": "error",
    "typescript/no-explicit-any": "error",
    "typescript/no-restricted-types": [
      "error",
      {
        "types": {
          "Record<string, unknown>": { "message": "Define explicit interfaces instead." },
          "Record<string, any>": { "message": "Define explicit interfaces instead." }
        }
      }
    ]
  }
}
```
