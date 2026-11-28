# Skill router

Unified discovery and loading for agent skills across Codex, Cursor, Claude Code, Crush, and other filesystem-based agents.

## Scopes and precedence

| Scope | Source | Precedence |
| --- | --- | --- |
| `repo` | `.cursor/skills`, `.claude/skills`, `.agents/skills`, `.codex/skills`, `.crush/skills`, `.factory/skills`, `.opencode/skills`, `.agent/skills`, `skills/`, and `modules/home/skills/` under the current cwd | Highest (3) |
| `workspace` | Same app-local dirs at the git root when cwd is nested inside a monorepo | 2 |
| `user` | App-native dirs plus `~/.config/agents/skills` and `~/.agents/skills`: Cursor, Claude, Codex, Crush, OpenCode, Factory/Droid, and Pi | Lowest (1) |

Higher precedence wins on id collision. Nix-managed user skills (`programs.agent-skills` in `modules/home/claude.nix`) remain the source of truth for the user scope; skill-router does not replace that provisioning.

## Progressive disclosure

1. **Startup**: agents receive only a compact routing instruction (`skill-router catalog --format compact`), not a skill catalog.
2. **Activation**: `skill-router load <scope:id>`.
3. **References**: follow `REFERENCE.md` or `scripts/` links inside `SKILL.md` only when needed.

Keep `SKILL.md` under ~100 lines; split detail into references (Matt Pocock discipline).

## Commands

```bash
skill-router discover                  # local scopes, merged precedence
skill-router discover --json
skill-router catalog --format compact  # tiny startup instruction, no skill list
skill-router catalog --format agents   # full available_skills block on demand
skill-router load user:diagnose        # print SKILL.md
skill-router sync --dry-run            # explicit symlink adapter (repo/workspace -> agent dirs)
skill-router install-agents            # merge compact block into AGENTS.md
```

## Per-agent notes

| Agent | Primary discovery | Repo skills |
| --- | --- | --- |
| Cursor | `~/.cursor/skills`, `~/.agents/skills`, plus compatibility dirs | auto in project |
| Claude Code CLI/Desktop Code tab | `~/.claude/skills` + plugins | `.claude/skills` in repo |
| Codex CLI/Desktop | `~/.agents/skills`, `~/.codex/skills` | `.agents/skills` or sync |
| Crush | `~/.config/agents/skills`, `~/.config/crush/skills`, `~/.agents/skills`, `~/.claude/skills` | `.crush/skills`, `.agents/skills`, `.claude/skills`, `.cursor/skills`, or sync |
| OpenCode | `~/.config/opencode/skills`, `~/.agents/skills`, `~/.claude/skills` | `.opencode/skills`, `.agents/skills`, or sync |
| Factory/Droid | `~/.factory/skills` | `.factory/skills` or sync |
| Zed | `~/.agents/skills` only | `.agents/skills` only |
| Generic | `AGENTS.md` `<available_skills>` | logical `repo:id` paths |

`skill-router install-agents` writes the compact startup instruction by default. It does not paste any skill catalog into `AGENTS.md`; agents discover the list on demand with `skill-router discover --json`.

`skill-router sync` is **explicit** and never runs at install or switch time. Use when an agent cannot resolve logical ids and needs filesystem symlinks.

## Configuration

Default: the CLI bundles `tools/skill-router/config.default.json`. Create `~/.config/skill-router/config.json` only for local directory or agent overrides; overrides merge onto the default.

## Nix integration

- Binary: Home Manager profile `skill-router` (Bun wrapper)
- User skill provisioning: unchanged in `modules/home/claude.nix` via `agent-skills-nix`
- Repo skill example: `modules/home/skills/jj/` (linked into all picker targets)
