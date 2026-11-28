# Skill visibility owns each harness's off list

Status: accepted

Claude Code and Codex previously kept separate hand-written "off" lists that did not consult `modules/home/skill-placement.nix`. Those lists accumulated dead entries (`migrate-to-shoehorn`) and partial hides (`qa` disabled in `~/.agents/skills` while still active in `~/.codex/skills`). We extended `skill-placement.nix` to compute **Skill visibility** (`skillPlacement.visibility.<harness>.<id>` = `on | off | absent`) from `harnessReads`, placed skills, `bundleSkills`, `foreignSkills`, and `skillsOff`. Claude's `skillOverrides: "off"` and Codex's `/etc/codex/config.toml` `[[skills.config]]` off entries now generate directly from that output.

## Considered options

- **Create a separate visibility module that imports `skill-placement.nix`.** Rejected: it needed the exact same host and harness tables, which showed placement and visibility belong in one module.
- **Keep hand-maintained off lists inside `claude.nix` and `codex.nix`.** Rejected: allowed dead skill IDs and unhidden mirror paths to drift silently.
- **Change the `Skill audience` of `qa` and `request-refactor-plan` instead of turning them off in Codex.** Rejected: Codex shares `~/.agents/skills` with Droid, Pi, and Antigravity, so dropping them from `~/.agents/skills` strips them from those harnesses too.
- **Compute visibility inside `skill-placement.nix` and enforce guide pointer resolution in `integration-configurations-eval` (chosen).** Fails the build if an `off` skill is absent from the harness's directories or if a guide references an `off` or `absent` skill.

## Consequences and trade-offs

- Adding a new skill host directory or agent harness requires updating `harnessReads` in `modules/home/skill-placement.nix` so visibility checks stay accurate.
- Claude Code plugin skills and **Parked skills** remain outside `skillPlacement.visibility` because only Claude Code has a plugin cache.
- **Reversal trigger:** If every harness reads only its own dedicated skill directory instead of sharing `~/.agents/skills`, replace `skillsOff` with `Skill audience` lists.
