# Reference Nix configurations

This directory contains full external sample repositories kept for study and comparison. They are **not active flake inputs**, are not imported by `../flake.nix`, and should not be copied wholesale into the live configuration.

## Contents

- `nix-config-kyura/` — Kyure-A style cross-platform nix-darwin/NixOS/Home Manager setup. Useful examples: program/package splits, Darwin defaults, fonts, MAS/Homebrew patterns, overlays, and agent-skills integration.
- `nixos-config-mitchellh/` — Mitchell Hashimoto style NixOS/nix-darwin setup. Useful examples: simple `mkSystem` composition, machine/user/home separation, WSL and VM scaffolding, and pragmatic Darwin integration.
- `agent-skills-nix-master/` — upstream-style Agent Skills Nix reference. Useful examples: Home Manager DSL, skill discovery, target syncing, local install scripts, and skill packaging patterns.
- `dotfiles-main/` — Sxyazi-style dotfiles reference containing mature zsh, tmux, lazygit, bat, less, yazi, kitty, nvim, mpv, and shared formatter/linter rule assets. Live implementations must copy/adapt selected files into root modules, not import this tree directly.

## Policy

Use these references to extract patterns, not as source of truth:

1. Live config stays in the repository root (`flake.nix`, `hosts/`, `modules/`, `pkgs/`, `lib/`).
2. Any borrowed idea must be rewritten for Martin's target order: Mac first, future Omakub Home Manager second, WSL/X230 scaffolds last.
3. Linux/NixOS-specific settings must not leak into nix-darwin modules.
4. Homebrew/MAS examples are reference material only; this repo defaults to pure Nix/custom derivations.
5. Agent Skills examples are reference material until `modules/home/skills.nix` is intentionally migrated to the upstream Home Manager DSL.
6. Dotfile assets borrowed from `dotfiles-main/` become maintained copies under `../modules/home/dotfiles/assets/`; `references/dotfiles-main/` remains source material only.
