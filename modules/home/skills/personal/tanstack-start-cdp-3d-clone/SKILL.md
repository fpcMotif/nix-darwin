---
name: tanstack-start-cdp-3d-clone
description: Scaffold TanStack Start + Tailwind v4 + Three.js web clones and run aligned CDP port 9222 verification
---

# Scaffolding TanStack Start + Tailwind v4 + Three.js Clones with CDP Verification

## Overview
Procedure for creating pixel-accurate web app clones built with TanStack Start, Tailwind CSS v4, and Three.js WebGL scenes, verified via Chrome DevTools Protocol (CDP port 9222).

## Procedure

1. **Scaffold TanStack Start Project**:
   ```bash
   bun create vite project-name --template react-ts
   cd project-name
   bun add @tanstack/react-router @tanstack/react-start lucide-react three clsx tailwind-merge
   bun add -D @tanstack/router-plugin tailwindcss @tailwindcss/vite @types/three
   ```

2. **Configure Vite (`vite.config.ts`)**:
   ```ts
   import { defineConfig } from 'vite'
   import react from '@vitejs/plugin-react'
   import tailwindcss from '@tailwindcss/vite'
   import { tanstackStart } from '@tanstack/react-start/plugin/vite'

   export default defineConfig({
     plugins: [
       tanstackStart(),
       react(),
       tailwindcss()
     ]
   })
   ```

3. **Configure TanStack Router (`src/router.tsx`)**:
   ```ts
   import { createRouter as createTanStackRouter } from '@tanstack/react-router'
   import { routeTree } from './routeTree.gen'

   export function createRouter() {
     return createTanStackRouter({
       routeTree,
     })
   }

   export const getRouter = createRouter

   export type AppRouter = ReturnType<typeof createRouter>

   declare module '@tanstack/react-router' {
     interface Register {
       router: AppRouter
     }
   }
   ```

4. **Wire Root Document Shell (`src/routes/__root.tsx`)**:
   ```tsx
   import { createRootRoute, Outlet, HeadContent, Scripts } from '@tanstack/react-router'
   import appCss from '../index.css?url'

   export const Route = createRootRoute({
     head: () => ({
       meta: [
         { charSet: 'utf-8' },
         { name: 'viewport', content: 'width=device-width, initial-scale=1' },
       ],
       links: [
         { rel: 'stylesheet', href: appCss }
       ]
     }),
     component: RootComponent,
   })

   function RootComponent() {
     return (
       <html lang="en">
         <head>
           <HeadContent />
         </head>
         <body>
           <Outlet />
           <Scripts />
         </body>
       </html>
     )
   }
   ```

5. **CDP Verification Protocol**:
   - Start Google Chrome with `--remote-debugging-port=9222`.
   - Open target reference site and local clone (`http://127.0.0.1:5173/`).
   - Use CDP WebSocket `Runtime.evaluate` & `Page.captureScreenshot` to capture aligned screenshots at key scroll steps (y=0, 250, 500, 750, 1000).
