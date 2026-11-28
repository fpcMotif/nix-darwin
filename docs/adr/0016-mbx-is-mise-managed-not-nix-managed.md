# mbx is mise-managed, not Nix-managed

Status: accepted

`mise` installs `mbx` (`mr-boxington`, the shared Cargo build cache) from `~/.config/mise/config.toml`. Running `mbx setup` writes a Cargo shim to `~/Library/Application Support/mbx/bin/cargo` that reads a sibling `mbx-target` path. Rather than packaging `mbx` in Nix before testing how its mutable shim behaves in `/nix/store`, Nix leaves `mbx` to `mise`. Nix places `~/Library/Application Support/mbx/bin` in the first **PATH tier** (`modules/home/shell/zsh.nix`) so `cargo` runs through `mbx`.

## Considered options

- **Package `mbx` and generate its Cargo shim in Nix immediately.** Rejected: `mbx setup` manages `mbx-target` at runtime, and packaging it blind risked breaking every local Cargo build.
- **Manage `mbx` in `mise` and order `PATH` in Nix (chosen).** Ships cached Cargo builds immediately while keeping the PATH priority declarative.

## Consequences and trade-offs

- On a fresh Mac, the `mbx/bin` PATH entry does nothing until `mise install` and `mbx setup` run; `cargo` falls through to Nix Cargo uncached.
- If `mise` removes `mbx` while the shim remains on disk, the shim falls back to any older `mbx` on `PATH` (such as `~/.cargo/bin/mbx`).
- **Reversal trigger:** Once a test confirms `mbx` runs from `/nix/store` behind a declarative Home Manager shim, package `mbx` in `pkgs/` as a release pin.
