# nix-config

Martin's cross-platform Nix configuration (nix-darwin is the active target; Linux/NixOS hosts are staged). This glossary pins terms that are overloaded across the repo's tooling so plans and code don't drift on vocabulary.

## Language

### Agent-skills curation

**superpowers**:
The upstream **obra/superpowers** repo, pinned as a Nix flake input and treated as the canonical source for the `brainstorming` skill. Bare "superpowers" always means this.
_Avoid_: using "superpowers" to mean the plugin — say "the superpowers plugin" for that.

**superpowers plugin**:
The `frad-dotclaude/superpowers` Claude Code plugin in `~/.claude/plugins/cache`. A divergent fork of obra's work with renamed/extra skills (`behavior-driven-development`, `need-vet`, `agent-team-driven-development`, `build-like-iphone-team`). Kept for its hooks/commands framework; its `brainstorming` is parked so only obra's surfaces.

**Parked skill**:
A skill deliberately moved into a sibling `skills-disabled/` directory so no skill picker can discover it. Used when a skill ships inside a third-party plugin we otherwise keep. Reversible and re-applied on every rebuild — distinct from a skill that is simply not enabled.

**Enabled skill** vs **Discovered skill**:
A *discovered* skill exists in the catalog (its source is wired up) but is not placed in any picker. An *enabled* skill is additionally surfaced into the picker target dirs and is selectable. Wiring a source discovers its skills; it does not enable them.

### Hosts & identity

**f**:
The active Mac's host identity — simultaneously the flake attribute (`darwinConfigurations.f`), the OS `HostName`/`LocalHostName` (so `f.local` on the LAN), and Martin's personal handle. Driven by the `hostname` argument threaded through `mkSystem`.
_Avoid_: conflating it with the Unix user or the display name.

**martinfan**:
The Unix user account (`/Users/martinfan`). The login is `martinfan`; the host identity is `f` — they are not the same thing.

**ComputerName**:
The human-facing device name in macOS Sharing/Finder — "Martin's Mac mini". Deliberately left readable and *not* set to `f`; only the technical `HostName`/`LocalHostName` are `f`.

## Flagged ambiguities

- **"superpowers"** — overloaded between obra/superpowers (the Nix-managed source; canonical) and frad-dotclaude/superpowers (the plugin; a fork). Resolution: bare "superpowers" = obra; always qualify the plugin as "the superpowers plugin".
- **"f"** — the host identity (flake attr ≡ OS `HostName`/`LocalHostName` ≡ personal handle), *not* the Unix user (`martinfan`) and *not* the display ComputerName ("Martin's Mac mini").

## Example dialogue

> **Dev:** Two `brainstorming` skills are showing up in the picker.
> **Maintainer:** obra's `brainstorming` is enabled from the Nix source, and the superpowers plugin ships its own. We park the plugin's so only obra's surfaces.
> **Dev:** What about the plugin's `writing-plans` and `executing-plans`?
> **Maintainer:** Those stay live — we park only the plugin's `brainstorming`, not its whole skills dir. obra's `writing-plans` is merely discovered, not enabled, so there's no clash.
