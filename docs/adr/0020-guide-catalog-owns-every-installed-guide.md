# The guide catalog owns every installed guide

Status: accepted

The guide catalog (`modules/home/agent-instructions/guides.nix`) is the one list of each agent host's guide files. A host has a startup guide, a development guide, language guides, a human-documents guide, and `extras`: reference files that its guides point to, such as `~/.codex/guidance/setup.md` and `~/.claude/search-routing.md`. The catalog exports `files` (target to source) and `targets`.

- `agent-instructions.nix` installs `files` and archives `targets` (`backupAgentInstructions`) on every system, Darwin and Linux. Codex profiles, omp routing files, omp agents, the writable Codex config, and the Codex skill off list stay under `mkIf isDarwin`.
- The catalog writes each host's `## Guides` section (the Develop, Languages, Documents, and Workspaces lines) from the host's targets, and adds the shared `## Search rules` section. Host adapters hold only what differs between hosts.
- `integration-configurations-eval` checks that every catalog target is a non-forced Home Manager file and is in the backup list. The guide pointer check (ADR-0019) reads the same catalog. It scans each host's guides and only those extras that the startup guide links.

Before this, `claude.nix` installed Claude's guides with no backup, so a Claude Code write to `~/.claude/CLAUDE.md` could stop a switch at `checkLinkTargets`. The other hosts' guides were installed only on Darwin, and the pointer check kept its own copy of the extras list.

## Considered options

- **Keep the guides Darwin-only.** Rejected. Guides are plain files, the Linux hosts can run Codex and omp, and Claude's guides were already on Linux.
- **Keep a per-host `platforms` field.** Rejected. No host needs a different platform set, so the field would be a hypothetical seam.
- **Let each harness module install its own guides.** Rejected. That split is how Claude's guides lost the backup.
