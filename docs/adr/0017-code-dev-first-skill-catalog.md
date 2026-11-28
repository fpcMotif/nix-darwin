# Skill catalog is code-dev-first; authoring and project-management skills stay global

Status: accepted

Every enabled skill and plugin in the global proactive catalog adds frontmatter tokens to every session in every repository. An audit showed that enabled Claude Code plugins dominate that context cost while the Nix skill bundle costs under 1%. We curate the global catalog around daily code-development fit (`disabledMattpocockSkills` and `leanExcludedMattpocockSkills`). Cross-repo authoring and project-management skills (`skill-creator`, `claude-md-management`, `to-spec`, `to-tickets`, `triage`, `writing-for-agents`, `grilling`) stay global so they work in any checkout. Local skills live as committed files under `modules/home/skills/` rather than store symlinks in the working tree.

## Considered options

- **Move authoring and project-management skills off the global catalog into per-repo `.agents/skills/` directories.** Rejected: issue filing, spec writing, and skill edits happen across many repositories; per-repo setup adds friction for under 1% token savings.
- **Symlink flake-input skill directories or `node_modules` skills directly into `modules/home/skills/` in the git checkout.** Rejected: content-addressed `/nix/store` symlinks change on every `nix flake update`, lack GC roots, and dirty `git status` if generated at activation time.
- **Commit local skills in `modules/home/skills/` and curate global plugins and bundle lists by task fit (chosen).** Keeps builds hermetic, offline, and GC-safe while bounding plugin bloat.

## Consequences and trade-offs

- Application repositories still see global skill-authoring and PM skills in their picker list, which costs ~0.7% of context for zero per-repo setup.
- Vendored skills under `modules/home/skills/` do not auto-bump with `flake.lock`; the maintainer updates them in git.
- Session-injected cloud skills (`anthropic-skills:*`) live outside local plugin caches, so `modules/home/claude.nix` cannot prune them.
- **Reversal trigger:** If global local skills cause measurable mis-triggering or context bloat in app repos, add an opt-in gitignored `.agents/skills/` sync profile.
