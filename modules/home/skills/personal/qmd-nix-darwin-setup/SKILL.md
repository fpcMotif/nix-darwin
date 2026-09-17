---
name: qmd-nix-darwin-setup
description: "Install, configure, and fix @tobilu/qmd SQLite dynamic extension loading on Nix-Darwin systems lacking Homebrew paths"
---

# QMD Setup & SQLite Compatibility on Nix-Darwin with Bun

## Problem
When installing `@tobilu/qmd` globally via Bun on macOS systems running Nix-Darwin without Homebrew:
1. `@tobilu/qmd`'s `dist/db.js` attempts to load macOS SQLite with dynamic extension support (`sqlite-vec`).
2. It loops through hardcoded Homebrew paths (`/opt/homebrew/opt/sqlite/lib/libsqlite3.dylib` and `/usr/local/opt/sqlite/lib/libsqlite3.dylib`).
3. Because neither path exists, `BunDatabase.setCustomSQLite(p)` throws inside a try-catch loop, leaving Bun's internal custom SQLite pointer poisoned with `/usr/local/...`.
4. Subsequent calls to `new Database(...)` crash with:
   `error: dlopen(/usr/local/opt/sqlite/lib/libsqlite3.dylib, 0x0001): tried: ... (no such file)`.

## Solution

### 1. Locate and Link Nix SQLite
Nix provides a full SQLite build with dynamic extension loading enabled.
Find the active Nix SQLite `.dylib`:
```bash
nix eval --raw 'nixpkgs#sqlite.out'
# e.g. /nix/store/<hash>-sqlite-3.53.3
```
Create a stable user symlink:
```bash
mkdir -p ~/.local/lib
ln -sf $(nix eval --raw 'nixpkgs#sqlite.out')/lib/libsqlite3.dylib ~/.local/lib/libsqlite3.dylib
```

### 2. Patch dist/db.js in @tobilu/qmd
In `~/.bun/install/global/node_modules/@tobilu/qmd/dist/db.js`, ensure `setCustomSQLite` checks `existsSync` and includes the local Nix path:
```javascript
if (process.platform === "darwin") {
    const { existsSync } = await import("node:fs");
    const candidatePaths = [
        process.env.SQLITE_LIB_PATH,
        (process.env.HOME || "") + "/.local/lib/libsqlite3.dylib",
        "/opt/homebrew/opt/sqlite/lib/libsqlite3.dylib",
        "/usr/local/opt/sqlite/lib/libsqlite3.dylib",
    ];
    for (const p of candidatePaths) {
        if (!p) continue;
        try {
            if (existsSync(p)) {
                BunDatabase.setCustomSQLite(p);
                break;
            }
        }
        catch { }
    }
}
```

### 3. Verify Health
```bash
qmd doctor
```
Expected output:
- `Runtime: bun:sqlite`
- `SQLite runtime: 3.53.x`
- `sqlite-vec: v0.1.9`
- `device probe: GPU metal (Apple Silicon)`
