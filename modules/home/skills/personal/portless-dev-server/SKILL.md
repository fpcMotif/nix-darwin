---
name: portless-dev-server
description: "Set up, configure, and troubleshoot Portless for local dev servers (Vite, Next.js, Bun) with named .localhost HTTPS domains and agent test harness integration"
---

# Portless Local Dev Server Setup & Integration

Procedure for setting up, configuring, and troubleshooting [Portless](https://github.com/vercel-labs/portless) to replace numeric ports with stable, named `.localhost` HTTPS URLs for local development, Vite projects, and agent visual verification harnesses.

## Core Concepts

- **Portless Proxy**: Local reverse proxy running on port 443 (or custom port via `PORTLESS_PORT`) routing `https://<app>.localhost` to an assigned ephemeral port (4000–4999).
- **HTTPS & HTTP/2**: Self-signed local CA generated automatically on first run and trusted system-wide.
- **Port Injection**: Passes `PORT` environment variable to child servers, or injects `--port` and `--host` for frameworks that ignore `PORT` (e.g. Vite).

## Installation

### Bun / Project Dev Dependency
```bash
bun add -d portless
# Ensure portless binary is in $PATH:
ln -sf "$(pwd)/node_modules/.bin/portless" ~/.bun/bin/portless
```

## Project Configuration

### 1. `portless.json`
Define the canonical app name:
```json
{
  "name": "myapp"
}
```
This serves the application at `https://myapp.localhost`.

### 2. `package.json` Scripts
Provide both proxied and direct fallback commands:
```json
{
  "scripts": {
    "dev": "portless myapp vite",
    "dev:direct": "vite",
    "preview": "portless myapp vite preview",
    "preview:direct": "vite preview"
  }
}
```

### 3. Vite Configuration (`vite.config.ts`)
Ensure Vite binds the dynamic port and permits `.localhost` host headers:
```ts
export default defineConfig({
  server: {
    port: process.env.PORT ? parseInt(process.env.PORT, 10) : 3000,
    host: true,
    allowedHosts: [".localhost", "localhost", "127.0.0.1"],
  },
});
```

### 4. Test & Harness Scripts
Scripts inspecting candidate servers (CDP, fetch, Puppeteer) should dynamically check `PORTLESS_URL`:
```ts
const defaultUrl = process.env.PORTLESS_URL || process.env.CANDIDATE_URL || "https://myapp.localhost";
let targetUrl = defaultUrl;
try {
  await fetch(defaultUrl, { method: "HEAD" });
} catch {
  // Fall back to direct localhost if proxy is not active
  targetUrl = "http://localhost:3000";
}
```

## Lifecycle & Troubleshooting

- **Check Health**: `portless doctor`
- **List Active Routes**: `portless list`
- **Safari Resolution**: Run `portless hosts sync` if Safari fails to resolve `.localhost` subdomains.
- **macOS Unprivileged Mode (No Sudo)**:
  Standard port 443 requires elevated permissions on macOS. If running without passwordless sudo:
  ```bash
  PORTLESS_PORT=1355 portless proxy start
  # Or run plain HTTP:
  portless proxy start --no-tls -p 8080
  ```
- **Bypass Proxy**:
  ```bash
  PORTLESS=0 bun run dev
  ```
