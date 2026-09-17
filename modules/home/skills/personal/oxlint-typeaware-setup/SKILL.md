---
name: oxlint-typeaware-setup
description: "Configure type-aware oxlint, oxfmt, and TypeScript check pipelines banning loose types like Recordstring, unknown"
---

# Type-Aware Oxlint & Oxfmt Setup Procedure

Use this skill when setting up or auditing a Vite/React TypeScript repository for type-aware linting with `oxlint`, `oxfmt`, and strict type rules banning `Record<string, unknown>`.

## 1. Install Dependencies
```bash
bun add -D oxfmt oxlint-tsgolint oxlint
```

## 2. Configure `.oxlintrc.json`
```json
{
  "$schema": "./node_modules/oxlint/configuration_schema.json",
  "options": {
    "typeAware": true
  },
  "plugins": ["react", "typescript", "oxc", "jsx-a11y"],
  "rules": {
    "react/rules-of-hooks": "error",
    "react/exhaustive-deps": "error",
    "typescript/no-explicit-any": "error",
    "typescript/no-restricted-types": [
      "error",
      {
        "types": {
          "Record<string, unknown>": {
            "message": "Use a specific interface or typed object instead of Record<string, unknown>"
          }
        }
      }
    ]
  }
}
```

## 3. Configure Scripts in `package.json`
```json
{
  "scripts": {
    "lint": "oxlint --deny-warnings",
    "format": "oxfmt --write .",
    "format:check": "oxfmt --check .",
    "typecheck": "tsc -b",
    "check": "bun run lint && bun run format:check && bun run typecheck"
  }
}
```

## 4. Verification
Run `bun run format && bun run check` to verify formatting, zero linter warnings, and clean TypeScript compilation.
