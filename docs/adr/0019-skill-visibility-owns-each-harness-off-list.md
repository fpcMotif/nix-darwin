# Skill visibility owns each harness's off list

Status: accepted

Skill placement (`modules/home/skill-placement.nix`) also answers **Skill visibility**: for each harness and skill, `skillPlacement.visibility.<harness>.<id>` is `on`, `off`, or `absent`. Each harness's off list is an input to that module. The settings that turn skills off are generated from its output:

- Claude Code: `claude.nix` sets `skillsOff.claude` from the curation lists. `skillOverrides: "off"` and the `claudeHidden` manifest field read `skillPlacement.offIds.claude`.
- Codex: `agent-instructions.nix` sets `skillsOff.codex`. `modules/darwin/codex.nix` writes one `[[skills.config]]` entry for each `skillPlacement.offLinks.codex` path into `/etc/codex/config.toml`. This follows the `codexRequirements` precedent: the system module reads a Home Manager option.

Before this, Claude and Codex each turned off skills that placement had just installed. The two lists did not consult placement. The Codex list named `migrate-to-shoehorn`, which nothing installs, and turned off `qa` only in `~/.agents/skills` while `~/.codex/skills` held a second copy.

## Rules

- A harness reads a fixed set of skill hosts (`harnessReads`). A folder not confirmed for a harness counts as not read, so its skills are `absent` there. Confirmed: Codex reads `.codex/skills` and `.agents/skills`, Droid reads `.factory/skills` and `.agents/skills`, omp reads its two `.omp/agent` folders and `.agents/skills` (its loader names "user home" `.agents/skills`), and Antigravity and agy read `.gemini/config/skills`.
- `integration-configurations-eval` also fails when a guide points at something its reader cannot reach. A skill pointer is written as `` `id` skill `` and resolves when its harness has the skill `on`, or when a Claude plugin supplies it. The shared `~/AGENTS.md` guide resolves against `~/.agents/skills`. A file pointer is a `~/` path that Home Manager installs or that the user owns (`~/devv`, `~/nix-config`, `~/.codex/config.toml`). Guides use `~/`, never `/Users/`.
- Bundle skills are recorded, not linked: `bundleSkills` lists the ids and the audience that the `agent-skills` input links them into.
- A skill that another tool installs, such as `review` from `~/.skillshub`, is declared per skill host in `foreignSkills`, so a harness can still turn it off.
- Claude Code plugin skills and **Parked skills** stay outside the module. Only Claude has plugins.
- `integration-configurations-eval` fails when an off id is not installed in a folder its harness reads. This catches dead entries like `migrate-to-shoehorn`.

## Considered options

- **A separate visibility module that reads placement.** Rejected. It would need placement's host and harness tables, and the deletion test showed the two halves describe one concept.
- **Keep per-harness off lists in each harness's own config.** Rejected. That is the drift this record removes.
- **Merge the curation lists into one per-skill status table.** Rejected by ADR-0009 and not reopened here. The lists in `skill-curation.nix` stay as written. Only their reader changed.
- **Change the audience of `qa` and `request-refactor-plan` instead of turning them off in Codex.** Rejected. Codex shares `~/.agents/skills` with Droid, pi, and others, so an audience change would remove the skills from those harnesses too.
