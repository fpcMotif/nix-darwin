# nix-config

Martin's cross-platform Nix configuration (`nix-darwin` is the active Mac target; Linux and NixOS hosts wait in stage). This glossary defines repository terms so plans and code keep one name per concept.

## Language

### Darwin baseline

**Darwin baseline**:
The reproducible Mac state Nix manages on host `f`: packages, defaults, launchd policy, and Home Manager handoffs.
_Avoid_: mutable app data, auth state.

**Darwin baseline activation state**:
The reversible ledger of launchd helpers and path markers Nix changed, so turning an option off restores state.
_Avoid_: one-off script.

**Background churn**:
Optional helper, updater, indexer, or diagnostic processes that run continuously without an active user task.
_Avoid_: core system daemons, user-launched app processes.

**Hotkey plane**:
The global shortcut layer that launches apps or forwards app shortcuts without managing window layout.
_Avoid_: window manager, app keymap, prompt search plane.

**Terminal-first split control**:
Managing coding panes (split, focus, resize, equalize) inside the terminal or multiplexer rather than macOS window tiling.
_Avoid_: desktop tiling, Spaces layout.

**Prompt vi mode**:
Vi keybindings for Zsh's line editor (ZLE) on the shell input line.
_Avoid_: unqualified "vi mode" (name tmux, Zed, or TUI).

**Prompt search plane**:
The Zsh prefix-chord keymap (`^G` plus a key) that opens fzf pickers for files, directories, processes, and Git objects.
_Avoid_: hotkey plane.

**Manual-only app**:
An application installed for user-launched sessions whose background launchd helpers stay off in the Darwin baseline.
_Avoid_: disabled app, uninstalled app.

**macOS health report**:
A local diagnostic snapshot of drift, disk pressure, crashes, backups, and Nix store state.
_Avoid_: telemetry, remote monitoring, skill hygiene.

### Shell sessions

**PATH tier**:
An ordered directory group in base `PATH` (shims, Nix profiles, user installers) where the first match wins.
_Avoid_: PATH priority, PATH layer.

### Writable app files

**Seeded file**:
A writable app config file Nix creates if missing and reconciles on declared keys while preserving runtime edits.
_Avoid_: store symlink, immutable config.

**Owned key**:
A key in a seeded file Nix sets each switch and deletes on retirement if unchanged.
_Avoid_: pinned setting, forced setting.

### Agent-skills curation

**Parked skill**:
A skill moved into `skills-disabled/` each rebuild so pickers skip it while its parent plugin stays installed.
_Avoid_: unenabled skill, deleted skill.

**Plugin-provided skill**:
A skill in both the shared bundle and a Claude plugin, hidden from the bundle on Claude Code only.
_Avoid_: parked skill.

**Skill hygiene**:
The automated drift checks confirming curation lists match upstream skills and every agent sees each skill at most once.
_Avoid_: health check.

**Skill bundle**:
The skills this flake builds from pinned flake inputs and links into every picker dir through `programs.agent-skills`. The module in `modules/home/skill-bundle.nix` owns its source table and enable list. It publishes the ids as `martin.agentSurface.bundleSkills`. A bundle skill is distinct from a placed skill, which Skill placement links per audience, and from a plugin skill.
_Avoid_: calling a placed skill or a plugin skill a bundle skill.

**Skill placement**:
The Nix module that maps each declared skill and audience to target host directories and computes skill visibility.
_Avoid_: manifest.

**Skill visibility**:
The per-harness status of a skill (`on`, `off`, or `absent`) derived from linked host directories and harness off-lists.
_Avoid_: skill hygiene, health check.

**Skill audience**:
A named group of skill host directories (`pickers`, `everywhere`, `outside-claude`, or `codex-family`) that a skill targets together.
_Avoid_: skill host, agent host.

**Skill host**:
A directory on disk where skill placement links skill folders for one or more agent harnesses to read.
_Avoid_: agent host, skill audience.

**Discovered skill**:
A skill that exists in a wired upstream source catalog before any rule selects it for placement.
_Avoid_: enabled skill.

**Enabled skill**:
A discovered skill that skill placement links into picker host directories for agents to load.
_Avoid_: discovered-only skill, parked skill.

**Transformed skill**:
A skill built from a pinned flake input whose `SKILL.md` undergoes build-time string replacement for local names.
_Avoid_: vendored fork, manual patch.

**Alias section**:
The mapping table added to a transformed router skill so references inside unmodified playbooks resolve to installed skills.
_Avoid_: per-file patch.

**Collapsed principles**:
A single combined skill built at eval time from upstream leaf principle skills, with one section per upstream identifier.
_Avoid_: upstream leaf skills.

**Role sheet**:
The single Nix-owned file (`~/.claude/pstack-models.md`) that maps pstack agent roles to model aliases.
_Avoid_: hardcoded per-skill model slugs.

### Skill-router effects

**Router runtime (`RouterRuntime`)**:
The injected capability record holding the process-spawn adapter, file-read adapter, environment variables, and config path for `skill-router`.
_Avoid_: `RouterConfig`, global `process.env`.

**Router context (`RouterContext`)**:
The per-call `{ runtime, config }` pair resolved once at the CLI entry point so commands never re-parse config.
_Avoid_: re-calling `loadConfig` in leaf modules.

**Command seam (`CommandRunner`)**:
The injected process-spawn function through which `skill-router` runs `git rev-parse` while blocking real spawns in tests.
_Avoid_: direct `Bun.spawn` calls in leaf modules.

**Skill-read seam (`ReadText`)**:
The injected file-content reader through which `skill-router` loads config files and skill bodies from memory or disk.
_Avoid_: full virtual filesystem.

### AI tooling surfaces

**Semantic job-routing policy**:
The shared Nix policy mapping work classes (`search`, `check`, `general`, `plan`, `economy`) to model families and effort.
_Avoid_: hardcoded per-adapter model IDs.

**Vendored agent CLI**:
An AI coding-agent binary packaged under `pkgs/` on the rebuild path, where stale hashes block builds.
_Avoid_: API-only access, GUI-managed app.

**Agent host**:
An AI coding agent application (Claude Code, Codex, OMP, or Antigravity) that reads installed agent guides.
_Avoid_: bare "agent", skill host.

**Agent guide**:
A Nix-assembled instruction file telling an agent host how to work, with eval-checked skill and file pointers.
_Avoid_: system prompt, ad-hoc rules file.

**Host adapter**:
The opening section of an agent guide that declares only tool names and search routes unique to that host.
_Avoid_: duplicating shared rules.

**API-only model access**:
Calling a model provider over HTTP via an API key, without a local CLI binary.
_Avoid_: vendored agent CLI.

### Version control and review

**Review host**:
The single proactive code-review skill (`code-review`) that owns branch, diff, and PR review requests.
_Avoid_: duplicate proactive review skills, forked review routers.

**Colocated contract**:
In a `.jj` and `.git` repo, Git reads work against `HEAD` (`@-`), while Git writes break JJ.
_Avoid_: banning Git reads, `git commit`.

**Workspace backend**:
The tool selected by `martin.development.workspaceBackend` for sibling checkouts: Worktrunk (`wt`, default) or experimental dojjo (`djo`).
_Avoid_: calling a JJ workspace a Git worktree.

### Auto-update cadence

**Heavy input**:
A flake input (`nixpkgs`) whose update rehashes much of the system closure and moves only on cadence day.
_Avoid_: ad-hoc lists outside `scripts/lib/auto-update.sh`.

**Light input**:
Any top-level flake input outside the heavy set, updated nightly by the auto-update workflow.
_Avoid_: hand-enumerating light inputs.

**Cadence day**:
The ISO weekday (Monday UTC) when the auto-update workflow bumps heavy inputs unless forced.
_Avoid_: hardcoding the weekday gate in workflow YAML.

**Glue derivation**:
A fast profile, activation, or config derivation rebuilt each switch that the source-build guard excludes.
_Avoid_: classifying unknown slow builds as glue.

**Vendored derivation**:
A package in `pkgs/` built locally from vendored source or lockfiles because no binary cache holds it.
_Avoid_: hand-written exemption lists, glue derivation.

**Rust toolchain derivation**:
A `rust-overlay` package unpacking prebuilt Rust archives locally in seconds, exempted by version and target triple.
_Avoid_: bare `rustc` or `cargo` prefixes.

**Release pin**:
A derivation under `pkgs/` fixed to an upstream version and URL whose version and hashes update together.
_Avoid_: rolling pin, `flake.lock` pin.

**Rolling pin**:
A derivation at an unversioned upstream URL where the publisher overwrites bytes in place, updated via `just refresh-rolling`.
_Avoid_: release pin.

### Hosts and identity

**f**:
The active Mac's host identity: flake output (`darwinConfigurations.f`), macOS `HostName` and `LocalHostName` (`f.local`), and personal handle.
_Avoid_: `martinfan`, `ComputerName`.

**martinfan**:
The Unix user account name (`/Users/martinfan`) on the active Mac and staged Linux profiles.
_Avoid_: `f`.

**ComputerName**:
The human-facing device name in Finder and AirDrop ("Martin's Mac mini"), kept distinct from the technical hostname `f`.
_Avoid_: setting `ComputerName` to `f`.
