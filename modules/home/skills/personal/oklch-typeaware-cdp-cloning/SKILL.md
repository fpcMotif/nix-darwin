---
name: oklch-typeaware-cdp-cloning
description: "Procedure for scaffolding web clones with OKLCH CSS colors, type-aware oxlint rules, and CDP visual verification"
---

# OKLCH Type-Aware CDP Web Cloning & Accessibility Verification

Procedure for scaffolding web app clones with high-precision OKLCH CSS colors, type-aware oxlint rules, and CDP visual & WCAG 2.1 AA verification.

## Procedure

1. **DOM & Style Extraction via CDP / agent-browser**:
   ```bash
   bunx agent-browser open https://target-url.com/
   bunx agent-browser set viewport 1440 900
   bunx agent-browser eval "(() => { /* extract DOM, styles, colors, layout metrics */ })()"
   ```

2. **Scaffold React + Vite + Tailwind CSS v4 Project**:
   ```bash
   bun create vite my-clone --template react-ts
   cd my-clone
   bun add lucide-react clsx tailwind-merge
   bun add -D tailwindcss @tailwindcss/vite oxlint oxfmt oxlint-tsgolint
   ```

3. **OKLCH Theme Token Setup (`src/index.css`)**:
   - Define all colors in OKLCH space (`oklch(L C H)`).
   - Create semantic utility classes (`.bg-app-root`, `.bg-surface-glass`, `.text-main-token`, `.text-accent-blue`, `.mac-dot-red`, etc.) derived from CSS variables.

4. **Zero-Magic-Colors & Structured Constants (`src/constants/siteData.ts`)**:
   - Extract all site metadata, feature lists, app names, step-by-step instructions, and mock data into typed constant modules.
   - Consume only semantic token classes in `.tsx` files.

5. **Strict Type-Aware Oxlint & Formatting**:
   - Configure `.oxlintrc.json` with `"options": { "typeAware": true }` and `"typescript/no-restricted-types"` banning `Record<string, unknown>`.
   - Run `bunx oxlint --deny-warnings && bunx oxfmt --check . && tsc -b`.

6. **WCAG 2.1 AA Audit via axe-core**:
   Inject `axe-core` into page context using `agent-browser eval` and verify `results.violations.length === 0`.
