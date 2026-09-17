---
name: bun-native-boundary-checker
description: Fast zero-dependency package boundary and circular dependency checker for Bun TypeScript projects
---

# Native Bun Package Boundary Checker

Enforce package entry-point boundaries and prevent circular dependencies in Bun-powered TypeScript monorepos/projects without external linters like `dependency-cruiser` or Babel transpilers.

## When to Use

Use this recipe when replacing heavy dependency linters (e.g. `dependency-cruiser` with Babel/SWC workarounds) with a native Bun script that runs in <50ms.

## Implementation Pattern

Create `scripts/check-package-boundaries.ts`:

1. **Path-Depth Boundary Classification**:
   - `src/packages/<pkg>/<file>`: Public entry point.
   - `src/packages/<pkg>/<subfolder>/<file>`: Private internal (`lib/`, `tests/`).

2. **Regex / Transpiler Import Extraction**:
   Capture static imports, `import type`, `export ... from`, and dynamic `import()`:
   ```ts
   const IMPORT_OR_EXPORT_REGEX =
     /(?:(import|export)(?:\s+(type))?\s+(?:(?:(?:\* as \w+|(?:[\w\s{},*]+))\s+from\s+)|)['"]([^'"]+)['"])|import\(\s*['"]([^'"]+)['"]\s*\)/gu;
   ```

3. **Enforce the 4 Rules**:
   - `entrypoint-boundary-from-app`: Outside code only imports package root entry points.
   - `entrypoint-boundary-across-packages`: Packages importing other packages only import root entry points.
   - `tests-through-entrypoints`: Tests inside `packages/<pkg>/tests/` only import entry points and test fixtures.
   - `no-circular`: Graph-wide DFS cycle detection on runtime (non-type-only) imports.

4. **CLI Runner**:
   - Use `Bun.Glob` to enumerate `src/**/*.{ts,tsx}`.
   - Read and parse files concurrently using `Promise.all` and `Bun.file(path).text()`.
   - Wire to `"lint:boundaries": "bun scripts/check-package-boundaries.ts"` in `package.json`.
