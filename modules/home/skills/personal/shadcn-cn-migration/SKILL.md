---
name: shadcn-cn-migration
description: "Migrate Tailwind CSS and shadcn/ui projects from tailwind-merge, clsx, or cnfast to the official compiled cn engine (cn@0.2.x)"
---

# Migrate Tailwind CSS & shadcn/ui to Official `cn` Engine

Procedure for replacing `tailwind-merge`, `clsx`, and early community utilities (`cnfast`) with the official compiled `cn` engine (`cn@0.2.x` by `@shadcn` and `@aidenybai`).

## 1. Context & Rationale

- **Package**: `cn` on npm (`https://github.com/shadcn-ui/cn`).
- **Engine**: Zero-dependency, compiled bitmask table lookup.
- **Performance**: ~11–17 ns/op (5× to 14× faster than `tailwind-merge`).
- **Bundle footprint**: ~44 kB raw / ~9.7 kB gzip (-44% smaller than `tailwind-merge` 103 kB and `cnfast` 95 kB).
- **Parity**: 100% differential parity with `tailwind-merge` v3 (Tailwind CSS v4 supported).

## 2. Migration Procedure

### Step 1: Install `cn` and Remove Legacy Dependencies
```bash
bun add cn
bun remove tailwind-merge cnfast
```
*Note: Keep `clsx` only if external packages like `class-variance-authority` declare a peer dependency on it.*

### Step 2: Update `src/lib/utils.ts`
Replace the double-wrapped `twMerge(clsx(inputs))` with the direct export:

```ts
export { cn, type ClassValue } from 'cn'
```

### Step 3: Remove Inline Icons Dependencies
If `lucide-react` is only used for 2–3 UI glyphs (such as `ChevronDownIcon`, `ChevronUpIcon`, `CheckIcon`), inline them as local SVGs:
```tsx
export function ChevronDownIcon(props: JSX.SVGAttributes<SVGSVGElement>) {
  return (
    <svg width={18} height={18} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="m6 9 6 6 6-6" />
    </svg>
  )
}
```
Then run `bun remove lucide-react` to eliminate 36 MB of unused React icon wrappers.

### Step 4: Verification
Run typecheck, tests, and runtime benchmarks:
```bash
bun run check
bun run bench:styling
```
Verify 0 regression in class merging:
- Single string base: ~80M ops/s
- Dynamic conditional classes: ~13M ops/s
- Conflicting overrides (`px-2` vs `px-4`): ~60M ops/s
- Complex CVA button multi-variant: ~85M ops/s
