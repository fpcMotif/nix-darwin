# Per-project Effect-TS skill (devShell-scoped)

`effect-ts` is deliberately **not** in the global Nix skill bundle
(`modules/home/claude.nix` sets `enableAll = [ ]`). It is dependency-scoped:
loaded only inside Effect repos that opt in, so its `SKILL.md` frontmatter never
sits in the routing catalog of unrelated projects, and the version you load
tracks the repo rather than a global flake pin.

## Use it in an Effect repo

1. Copy `devshell.flake.nix` to the repo root as `flake.nix` (or merge its
   `inputs`/`devShells` into an existing flake).
2. Add direnv wiring so every agent launched from the project inherits the shell:

   ```sh
   echo 'use flake' > .envrc
   direnv allow
   ```

   Or run `nix develop` manually.

3. On shell entry the Effect-TS `SKILL.md` is copy-tree'd into this repo's
   `./.claude/skills/effect-ts` and `./.agents/skills/effect-ts`. Claude Code,
   Codex, and Cursor launched from here now discover it (and only here).

## Notes

- **Repo-scope precedence.** A project-local skill outranks the global user
  bundle (`repo > workspace > user`), so this effect-ts copy wins over anything
  global without polluting other repos.
- **Won't clobber.** The copy-tree install refuses to overwrite a non-store
  directory unless `AGENT_SKILLS_FORCE=1`, so hand-authored repo skills are safe.
- **Git-ignore the copies.** Add `/.claude/skills/effect-ts` and
  `/.agents/skills/effect-ts` to the project's `.gitignore` — they are generated.
- **Re-enable globally** (undo the demotion) by restoring
  `enableAll = builtins.attrNames effectSources;` in `modules/home/claude.nix`.

This mirrors agent-skills-nix's `examples/devshell`; the template locks its own
inputs on first `nix develop`.
