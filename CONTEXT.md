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


**Prompt vi mode**:
Vi keybindings for zsh's line editor (ZLE), provided by the `zsh-vi-mode` plugin behind `martin.shell.viMode` in `modules/home/zsh.nix`. It governs the input line only: normal/insert modes, motions, text objects, surround, per-mode cursor shape. Distinct surfaces keep their own names: tmux copy-mode (`mode-keys vi`, scrollback selection), Zed's `vim_mode` (editor), and the vim modes built into AI CLI TUIs.
_Avoid_: calling tmux copy-mode, Zed's `vim_mode`, or an AI CLI TUI's vim mode "vi mode" without a qualifier.


**Manual-only app**:
An app that may be installed or launched manually while its background launchd helpers are kept out of the baseline. Manual-only means user-initiated use is preserved; always-on helper behavior is not.
_Avoid_: disabled app, uninstalled app.

**macOS health report**:
A local diagnostic snapshot for the Mac's own maintenance loop, not telemetry and not a remote monitoring system. It exists to make drift, storage pressure, crashes, backups, and Nix garbage-collection state inspectable.
_Avoid_: monitoring, analytics, metrics pipeline.

### Agent-skills curation

**Parked skill**:
A skill deliberately moved into a sibling `skills-disabled/` directory so no skill picker can discover it. Used when a skill ships inside a third-party plugin we otherwise keep. Reversible and re-applied on every rebuild — distinct from a skill that is simply not enabled.

**Plugin-provided skill**:
A skill that is in this flake's bundle *and* declared by an enabled Claude Code plugin, so Claude Code would list it twice. The plugin copy wins on the Claude surface — it tracks upstream faster than the flake pin — and the bundle copy is hidden with `skillOverrides: "off"` in `~/.claude/settings.json`, a file no other agent reads. The id stays in the bundle and stays live in the other eight picker dirs, because Codex/Droid/OpenCode/Crush have no plugin system. Distinct from a *parked* skill, which is hidden from every picker.

**Skill hygiene**:
The drift checks over the curation lists: Tier 1 `unit-skill-hygiene` (hermetic — exclusion terms still name live upstream skills, no vendored fork shadows a promoted id, no `transform` returns to a mattpocock skill) and Tier 2 `just verify-skills` (live — every id advertised to Claude exactly once, every hidden id genuinely replaced by the plugin, every other agent still sees the full bundle). Deliberately not called a "health check": `martin.healthCheck` already owns that term for the macOS health report.

**Enabled skill** vs **Discovered skill**:
A *discovered* skill exists in the catalog (its source is wired up) but is not placed in any picker. An *enabled* skill is additionally surfaced into the picker target dirs and is selectable. Wiring a source discovers its skills; it does not enable them.
Rejected workflow skills should be removed from source filters instead of left discovered-but-disabled.

### Skill-router effects

**Router runtime (`RouterRuntime`)**:
The injected runtime record that carries the effect adapters and process environment used by `skill-router`: `run` (Command seam), `readText` (Skill-read seam), `env`, and optional `configPath`. Production uses `defaultRuntime`; tests pass a runtime with a recording command adapter, controlled `HOME`, and a test config path. This is the seam for config/env loading — tests should not mutate `process.env.HOME` to make discovery work.
_Avoid_: using this term for `RouterConfig` (the parsed config data) or for a long-lived application context with unrelated state.

**Router context (`RouterContext`)**:
The once-per-invocation `{ runtime, config }` pair resolved at the `cli.ts` edge by `resolveContext` and threaded through every module. Config is read and merged exactly once here; downstream modules read `ctx.config` and `ctx.runtime` rather than re-calling `loadConfig` — so a `catalog`/`install`/`sync` command no longer parses config twice. The `RouterRuntime` carries *how/where* (effect adapters + env); the `RouterContext` adds the resolved *what* (parsed config).
_Avoid_: calling `loadConfig` from a downstream module (resolve once at the edge and pass `ctx`), or putting per-request data like `cwd` on it — `cwd` stays a separate argument.

**Command seam (`CommandRunner`)**:
The injected process-spawn capability `run(argv) → { exitCode, stdout }` through which every external-process call in `skill-router` flows — the dormant-by-default `intentRunner` (`bunx @tanstack/intent@…`, package scope) and `git rev-parse` (workspace scope). Production wires `bunCommandRunner`; tests wire a recording adapter that captures the full argv (the pinned binary included) and returns scripted output. The seam expresses only *how* a process launches, never *when* — the `includePackage` gate and the `@0.0.41` pin stay above it, and offline/ENOENT degrades to `[]`/`null` inside the adapter rather than throwing. `bunCommandRunner` refuses to run under `bun test`, so a forgotten injection fails loud and offline instead of spawning the pinned runner over the network.
_Avoid_: using this term for the `intentRunner` command string (that is data the seam executes), or for build/activation-time work — the seam is never on the `darwin-rebuild` path (see `docs/adr/0006`).

**Skill-read seam (`ReadText`)**:
The injected file-read capability `read(path) → string | null` through which `skill-router` reads file *contents*: the `config.json` files (via `loadConfig`) and a resolved skill's body (the `loadSkill` / `loadIntentSkill` path). Production wires `bunReadText`; tests wire a reader that serves package bodies from memory with a real-file fallback, so the load path is exercised without staging skill files on disk. Distinct from directory discovery, which still walks the real filesystem.
_Avoid_: widening this to *all* file I/O — directory listing, symlinking, and writes stay on the real filesystem; it reads file contents, it is not a virtual filesystem.

**intentRunner**:
The command *string* (e.g. `bunx @tanstack/intent@0.0.41`) that `config.catalog` hands to the Command seam — *data the seam executes*, distinct from the `CommandRunner` capability that executes it. The source parameter is spelled `runnerCmd` to keep the string one rename away from the `run` capability.
_Avoid_: conflating `intentRunner`/`runnerCmd` (what to exec) with `run`/`CommandRunner` (how to exec).

### AI tooling surfaces

**Vendored agent CLI**:
An AI coding-agent binary packaged under `pkgs/` and installed via `home.packages` (codex, droid, opencode, amp, pi, oh-my-pi). It lives on the `darwin-rebuild` build path, so its upstream pinning is a maintenance surface for the whole system rebuild — a stale source hash wedges the rebuild, not just that one tool.
_Avoid_: conflating it with a model used only over its API, or with a GUI app launched from the hotkey plane.

**API-only model access**:
Use of an AI model purely over its provider API from inside an editor or agent — e.g. a Zed `agent_servers` favorite model plus the provider's `*_API_KEY` env. There is no binary and nothing on the build path.
_Avoid_: assuming API-only model access implies an installed CLI for that provider.

### Hosts & identity

**f**:
The active Mac's host identity — simultaneously the flake attribute (`darwinConfigurations.f`), the OS `HostName`/`LocalHostName` (so `f.local` on the LAN), and Martin's personal handle. Driven by the `hostname` argument threaded through `mkSystem`.
_Avoid_: conflating it with the Unix user or the display name.

**martinfan**:
The Unix user account (`/Users/martinfan`). The login is `martinfan`; the host identity is `f` — they are not the same thing.

**ComputerName**:
The human-facing device name in macOS Sharing/Finder — "Martin's Mac mini". Deliberately left readable and *not* set to `f`; only the technical `HostName`/`LocalHostName` are `f`.

## Flagged ambiguities

- **"f"** — the host identity (flake attr ≡ OS `HostName`/`LocalHostName` ≡ personal handle), *not* the Unix user (`martinfan`) and *not* the display ComputerName ("Martin's Mac mini").
- **"Gemini"** — formerly spanned every AI tooling surface at once (the vendored CLI `gemini-cli-preview`, a Zed favorite model, `GEMINI_*`/`GOOGLE_API_KEY` env, and a `⌃⌥⇧g` app-launcher hotkey) and was deliberately removed in full (see `docs/adr/0002`). Treat the reappearance of any Gemini surface as a regression, not a gap to fill.

## Example dialogue

> **Dev:** Should we package Dropbox as a `pkgs.martin.*` derivation like Drive and Raycast?
> **Maintainer:** No — Dropbox is the deliberate exception (see `docs/adr/0005`). Its self-updater rewrites its own bundle and its server can force-deprecate old clients, so vendoring it into the read-only store fights the app on every update. Install it natively and let it self-update; re-adding a Nix scaffold is a regression, not a gap.
> **Dev:** Is the macOS health report a monitoring stack?
> **Maintainer:** No. It is a local snapshot for maintenance evidence, so it belongs in the baseline without adding remote telemetry.
