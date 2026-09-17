---
name: varlock-setup
description: "Set up Varlock schema validation, type generation, and leak scanning in Bun / Vite / WXT projects"
---

# Varlock Setup Guide

Setup Varlock environment variable management, type safety, and leak scanning in Bun / Vite / WXT TypeScript projects.

## Installation & Config

1. Install `varlock` and `@varlock/vite-integration` as dev dependencies:
   ```bash
   bun add -D varlock @varlock/vite-integration
   ```

2. Create `bunfig.toml` to prevent Bun auto-loading conflicts:
   ```toml
   [env]
   env = false
   ```

3. Initialize schema non-interactively or manually create `.env.schema`:
   ```bash
   bunx varlock init --agent
   ```

4. Define `.env.schema` with `@type`, `@sensitive`, and `@defaultRequired`:
   ```env
   # @defaultRequired=false @defaultSensitive=false
   # @generateTsTypes(path=env.d.ts)
   # ----------

   # Description here
   # @type=url
   API_URL=

   # @sensitive
   API_SECRET=
   ```

5. Configure `vite.config.ts`:
   ```ts
   import { defineConfig } from "vite";
   import { varlockVitePlugin } from "@varlock/vite-integration";

   export default defineConfig({
     plugins: [varlockVitePlugin(), ...],
   });
   ```

6. Update `package.json` scripts:
   ```json
   {
     "scripts": {
       "prepare": "varlock codegen",
       "env:check": "varlock load",
       "env:scan": "varlock scan"
     }
   }
   ```

7. Update `tsconfig.json` to include `env.d.ts` in `"include"`:
   ```json
   {
     "include": ["src", "tests", "*.config.ts", "env.d.ts"]
   }
   ```

8. Clean up `src/vite-env.d.ts` so `env.d.ts` is the single source of truth for `ImportMetaEnv`:
   ```ts
   /// <reference types="vite/client" />
   ```

9. Generate TypeScript definitions:
   ```bash
   bun run prepare
   ```
