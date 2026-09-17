---
name: plasmo-mermaid-bundling
description: How to bundle Mermaid.js inside Chrome Extension content scripts using Plasmo/Parcel without dynamic chunk splitting 404 errors
---

# Bundling Mermaid.js in Chrome Extensions (Plasmo / Parcel)

## Problem

When building a Chrome MV3 Extension (with Plasmo / Parcel) that bundles `mermaid` inside a Content Script, Mermaid v11 uses dynamic `import()` for diagram definitions (`flowDiagram`, `sequenceDiagram`, etc.). Parcel splits these into separate async chunks (`flowDiagram-xxx.js`), which fail at runtime in content scripts with `Error: Cannot find module '<chunkId>'` because the browser attempts to fetch chunks relative to the host page's origin (`https://example.com/chunk.js` -> 404).

## Solution

1. In `src/types/data-text.d.ts`, declare the `data-text:*` asset module:
```ts
declare module 'data-text:*' {
  const content: string;
  export default content;
}
```

2. In `src/core/mermaid-lib.ts`, import `mermaid.min.js` as raw text and patch the esbuild namespace so it executes cleanly in standalone global scope without code-splitting:
```ts
import type { Mermaid } from 'mermaid';
import mermaidSource from 'data-text:mermaid/dist/mermaid.min.js';

let initializedMermaid: Mermaid | null = null;

export function getMermaidInstance(): Mermaid {
  if (initializedMermaid) return initializedMermaid;

  const globalScope = globalThis as unknown as {
    mermaid?: Mermaid;
    __esbuild_esm_mermaid_nm?: Record<string, { default: Mermaid }>;
  };

  if (globalScope.mermaid && typeof globalScope.mermaid.render === 'function') {
    initializedMermaid = globalScope.mermaid;
    return initializedMermaid;
  }

  try {
    globalScope.__esbuild_esm_mermaid_nm = globalScope.__esbuild_esm_mermaid_nm || {};
    const patchedCode = mermaidSource.replace(
      'var __esbuild_esm_mermaid_nm;',
      'globalThis.__esbuild_esm_mermaid_nm = globalThis.__esbuild_esm_mermaid_nm || {}; var __esbuild_esm_mermaid_nm = globalThis.__esbuild_esm_mermaid_nm;'
    );
    const runScript = new Function(patchedCode);
    runScript();
  } catch (e) {
    console.error('[Mermaid Initialization Error]', e);
  }

  if (globalScope.mermaid && typeof globalScope.mermaid.render === 'function') {
    initializedMermaid = globalScope.mermaid;
    return initializedMermaid;
  }

  throw new Error('Failed to initialize standalone Mermaid instance from bundled source');
}
```

3. Queue `mermaid.render` calls asynchronously to prevent ID collisions when multiple React components mount concurrently:
```ts
let renderQueue = Promise.resolve();

export async function executeMermaidRender(id: string, code: string): Promise<{ svg: string }> {
  const currentRender = renderQueue.then(async () => {
    const mermaid = getMermaidInstance();
    return await mermaid.render(id, code);
  });
  renderQueue = currentRender.then(() => {}, () => {});
  return currentRender;
}
```
