---
name: codewiki-clone-cdp-workflow
description: Procedure for scaffolding TanStack Start + Tailwind v4 + Three.js web clones and running aligned CDP port 9222 visual verification
---

# TanStack Start + Tailwind CSS v4 + Three.js Web Clone & CDP Verification Workflow

## Overview
Procedure for creating pixel-accurate web app clones using TanStack Start, Tailwind CSS v4, Three.js, and performing CDP remote debugging (port 9222) visual and metric verification.

## 1. Project Scaffolding with Bun
```bash
bun create vite <project-name> --template react-ts
cd <project-name>
bun add @tanstack/react-router @tanstack/react-start lucide-react three clsx tailwind-merge
bun add -D @tanstack/router-plugin tailwindcss @tailwindcss/vite @types/three @types/node
```

## 2. Vite & TanStack Start Configuration (`vite.config.ts`)
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
  ],
})
```

## 3. Router Setup (`src/router.tsx`)
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

## 4. Root Document Shell (`src/routes/__root.tsx`)
```tsx
import { createRootRoute, Outlet, HeadContent, Scripts } from '@tanstack/react-router';
import appCss from '../index.css?url';

export const Route = createRootRoute({
  head: () => ({
    meta: [
      { charSet: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      { title: 'App Title' },
    ],
    links: [
      { rel: 'stylesheet', href: appCss },
    ],
  }),
  component: RootComponent,
});

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
  );
}
```

## 5. CDP Remote Debugging & Recapture (Port 9222)
1. Start Google Chrome on port 9222:
   ```bash
   "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-cdp-profile "http://127.0.0.1:5173/" "https://target-url.com/"
   ```
2. Inspect & recapture using CDP WebSocket:
   - Set device metrics override: `{ width: 1440, height: 900, deviceScaleFactor: 2, mobile: false }` for desktop and `{ width: 390, height: 844, deviceScaleFactor: 3, mobile: true }` for mobile.
   - Calculate section-relative scroll progress: `scrollProgress = (window.scrollY - sectionTop) / (sectionHeight - window.innerHeight)`.
