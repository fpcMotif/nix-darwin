---
name: ast-grep-boundary-checker
description: "Enforce declarative package boundaries, architectural rules, and structural AST linting using ast-grep and OMP LSP ambient diagnostics"
---

# AST-Grep Package Boundary & Architecture Linter

Use `ast-grep` for instantaneous (<5ms) structural code analysis, deep-module package boundary enforcement, and real-time LSP diagnostics inside Oh My Pi (OMP).

## Core Concepts

1. **`sgconfig.yml`**: Placed at repository root to register rule directories (`ruleDirs: [rules]`).
2. **Declarative Rules (`rules/*.yml`)**: Tree-sitter AST pattern matching that flags illegal structural patterns (e.g. importing from private `lib/` subfolders).
3. **Ambient OMP LSP**: Real-time feedback delivered directly into OMP `<system-notice>` whenever files are edited.
4. **Virtual OMP Devices**: Direct AST queries via `xd://ast_grep` and AST-level rewrites via `xd://ast_edit`.

## Configuration Recipe

### 1. `sgconfig.yml` (Project Root)
```yaml
ruleDirs:
  - rules
```

### 2. Deep Package Boundary Rule (`rules/no-package-internals-ts.yml`)
```yaml
id: no-package-internals-ts
language: TypeScript
severity: error
message: "Deep package boundary violation: imports from '@/packages/$PKG/...' must use root entry points, not private subfolders."
rule:
  any:
    - pattern: import { $$$ } from "$PATH"
    - pattern: import type { $$$ } from "$PATH"
    - pattern: import $DEFAULT from "$PATH"
    - pattern: import type $DEFAULT from "$PATH"
    - pattern: import * as $NS from "$PATH"
    - pattern: import type * as $NS from "$PATH"
    - pattern: import "$PATH"
    - pattern: export { $$$ } from "$PATH"
    - pattern: export type { $$$ } from "$PATH"
    - pattern: export * from "$PATH"
    - pattern: export * as $NS from "$PATH"
    - pattern: import("$PATH")
  regex: '@/packages/[^/]+/[^/]+/'
```

Create an identical file for TSX with `language: Tsx` (`rules/no-package-internals-tsx.yml`).

### 3. OMP Ambient LSP Configuration (`~/.omp/lsp.json` or `.omp/lsp.json`)
```json
{
  "servers": {
    "ast-grep": {
      "command": ["ast-grep", "lsp"],
      "languages": ["typescript", "typescriptreact", "javascript", "javascriptreact"],
      "rootPatterns": ["sgconfig.yml", "sgconfig.yaml", ".ast-grep"]
    }
  }
}
```

## Operations

- **Scan Entire Repo**: `bunx ast-grep scan` (or native `ast-grep scan`)
- **Query via OMP Device**: Write JSON `{ "pat": "import { $$$ } from '$PATH'", "path": "src" }` to `xd://ast_grep`
- **Refactor via OMP Device**: Write AST rewrite operations to `xd://ast_edit` and resolve with `xd://resolve`
