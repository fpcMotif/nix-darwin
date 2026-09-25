# mbx is mise-managed, not Nix-managed

Status: accepted

Date: 2026-09-23

mbx (the mise tool `mr-boxington`) is a shared Cargo build cache. mise installs it from `~/.config/mise/config.toml`, and `mbx setup` writes its cargo shim to `~/Library/Application Support/mbx/bin/cargo`. Nix neither packages mbx nor writes the shim; it only orders around it. The shim directory is the first PATH tier in `home.sessionPath` (`modules/home/zsh.nix`), so plain `cargo` in zsh runs through mbx.

## Why

- The shim reads `mbx-target`, an absolute path to the mise-installed mbx, and execs it in shim mode. Nobody has checked whether mbx runs from a read-only store path, or which Cargo it would pick behind a Nix-written shim. Packaging it blind risks breaking every Cargo build.
- The PATH fix did not depend on who owns the binary, so it shipped without waiting for that check.

## Consequences

- A fresh Mac gets the PATH entry after one switch, but no shim until `mise install` and `mbx setup` run. Until then the entry points nowhere, and plain `cargo` falls through to the Nix Cargo: builds work, uncached.
- If mise removes mbx while the shim remains, the shim falls back to any `mbx` on PATH. Today that is a stale 1.11.1 copy in `~/.cargo/bin`.
- Revisit when a probe shows mbx running from the store and a Home Manager-written shim delegating to the intended Cargo. Then package mbx as a release pin (`au_bump_release`).
