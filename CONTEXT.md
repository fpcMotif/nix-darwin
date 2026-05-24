# nix-config

Martin's cross-platform Nix configuration (nix-darwin is the active target; Linux/NixOS hosts are staged). This glossary pins terms that are overloaded across the repo's tooling so plans and code don't drift on vocabulary.

## Language

### Darwin baseline

**Darwin baseline**:
The Nix-managed shape of the active Mac (`f`): system packages, macOS defaults, launchd policy, and Home Manager handoff points that should be reproducible after `darwin-rebuild switch`.
_Avoid_: using this term for mutable app data, auth state, caches, or personal files outside the Nix configuration.

**Darwin baseline activation state**:
The reversible local state the Darwin baseline owns during activation, such as launchd helper suppression ledgers and managed path markers. It records only changes made by Nix so disabling a baseline feature can clean up or restore its own effects without touching unmanaged app or user state.
_Avoid_: using this term for arbitrary activation scripts, mutable app settings, or one-off filesystem setup with no reversible ownership record.

**Background churn**:
Unwanted helper, updater, indexing, or diagnostic activity that keeps running without an explicit current task. The Darwin baseline suppresses background churn when the main app or development tree remains available by other deliberate workflows.
_Avoid_: treating every background process as churn; only use this for optional activity that competes with the user's Nix-managed baseline.

**Hotkey plane**:
The small, low-privilege global shortcut layer for launching apps or forwarding existing app-native shortcuts. It is not a macOS window-manager policy and should not own rich app/window state.
_Avoid_: using this term for app-local keymaps, text-editor shortcuts, or launcher search.

**Terminal-first split control**:
The preferred coding-layout control path: split, move between, resize, and equalise terminal panes from terminal-native mechanisms before reaching for macOS-wide tiling.
_Avoid_: treating every window split as a Finder/Dock/Spaces concern; most coding splits belong inside the terminal session.


**Manual-only app**:
An app that may be installed or launched manually while its background launchd helpers are kept out of the baseline. Manual-only means user-initiated use is preserved; always-on helper behavior is not.
_Avoid_: disabled app, uninstalled app.

**macOS health report**:
A local diagnostic snapshot for the Mac's own maintenance loop, not telemetry and not a remote monitoring system. It exists to make drift, storage pressure, crashes, backups, and Nix garbage-collection state inspectable.
_Avoid_: monitoring, analytics, metrics pipeline.

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

> **Dev:** Dropbox is packaged, so should it be in the Darwin baseline?
> **Maintainer:** Not unless we explicitly want the client and its helpers always running. Otherwise it is background churn; keep the app path opt-in and preserve a quiet baseline.
> **Dev:** Is the macOS health report a monitoring stack?
> **Maintainer:** No. It is a local snapshot for maintenance evidence, so it belongs in the baseline without adding remote telemetry.
