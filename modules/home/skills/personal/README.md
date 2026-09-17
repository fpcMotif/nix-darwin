# Personal skill sources

These directories preserve the personal skills installed on the active Mac on 2026-09-12.
`manifest.json` maps each source to its existing discovery and installer paths.
`agent-instructions.nix` links every listed path to the same immutable source.

Edit skills here, then rebuild. Do not edit their generated home-directory symlinks.
The migration archives existing directories and links under `~/.local/state/nix-agent-backups/`.
Duplicate copies have matching contents; their discovery paths remain unchanged.
OMP-specific skills retain their native directories and conditional instruction pointers.

Upstream curated skills remain pinned through `programs.agent-skills` in `claude.nix`.
Codex `.system` skills and Codex/Claude plugin caches remain owned by their native installers.
Plugin-specific skills are not copied into this source tree.
Installer updates that replace a managed link must be reviewed and imported here before rebuilding.

`simplify` ports Claude Code's built-in `/simplify` to Codex, Amp, agy, and OMP.
Its manifest entry omits `.claude/skills`, so Claude Code keeps its built-in.
Claude Code does not scan `~/.agents/skills`, so the shared link never reaches it.
Hiding it through `skillOverrides` would match by name and could hide the built-in too.

The import excludes dependency directories, version-control metadata, bytecode, and filesystem cache files.
Supporting scripts, references, executable permissions, and the Surge image asset are preserved.
