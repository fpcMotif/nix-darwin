# Skill catalog is code-dev-first; authoring and project-management skills stay global

Status: accepted (amended 2026-10-18: authoring and PM skills stay on the global catalog)

`skill-router` merges skill scopes by precedence, but what the model sees *without being asked* is the **global proactive catalog**. That catalog has three parts: the Nix agent-skills bundle (`enabledMattpocockSkills` in `modules/home/claude.nix`), the local skills under `modules/home/skills/`, and the enabled Claude Code plugins in `~/.claude/plugins/cache`. Its size is a per-project context cost paid on every session in every repo. The skill-system audit established the shape of that cost: the Nix bundle is cheap (~0.7%) and the **enabled-plugin catalog is the dominant term** — which is why the prior plugin-dial pulls (several MCP/docs-lookup and git-flow plugins — see `docs/adr/0003`) targeted plugins, not bundle skills.

This repo's agents work overwhelmingly in **code-dev** repos. Skills whose subject is *authoring skills or agent configuration* never fire while writing application code, and they add catalog noise that can mis-trigger. The `leanExcludedMattpocockSkills` list exists to trim that kind of noise ("signal/noise, not broken").

## Decision

1. **The global proactive catalog is code-dev-first.** Membership is curated by *task-fit*, not by "broken vs working". `disabledMattpocockSkills` holds skills that are off for a reason of fit (today `grill-me`, superseded by the `grilling` + `grill-with-docs` pair). `leanExcludedMattpocockSkills` holds skills trimmed as noise. It is empty today.
2. **Authoring and project-management skills stay on the global catalog.** An earlier version of this ADR moved them off the global surface. That follow-up never landed, and the decision now matches the code:
   - The `skill-creator@claude-plugins-official` and `claude-md-management@claude-plugins-official` plugins are seeded as enabled in `modules/home/claude.nix`. They are not in `disabledClaudePlugins`.
   - The mattpocock PM skills (`to-spec`, `to-tickets`, `triage`) and the authoring skill `writing-for-agents` ship in the global bundle through the `engineering` and `productivity` buckets.
   - Design skills (`grilling`, `grill-with-docs`) are global for the same reason: they apply in any repo.
3. **Local skills are global.** Each directory under `modules/home/skills/` that holds a `SKILL.md` directly is linked by Home Manager into every picker dir (`.claude/skills`, `.agents/skills`, `.codex/skills`, and the other skill link targets except Factory). Those skills show up in every repo, not only in `nix-config`. `skill-router` also finds them in repo scope when the working directory is this checkout, so in `nix-config` they resolve from both scopes.
4. **A skill can be scoped to one repo only through that repo's own skill dirs.** No skill in `nix-config` uses this today. A repo that wants a skill off the global catalog commits it to its own repo-scope dir (for example `.agents/skills/` in that repo) and keeps it out of `modules/home/skills/`.

## Why vendored, not symlinked from the store

A local skill is a **committed copy** under `modules/home/skills/<name>/` (the `jj` precedent: a real `SKILL.md` in git), not a symlink. The symlink alternatives were considered and rejected because they fail on Nix's own terms.

**Repo scope is discovered from the working tree, but Nix content lives in the store.** `skill-router` finds repo skills by walking `$cwd/modules/home/skills` — the literal git checkout. A flake input (`inputs.mattpocock-skills`) only ever materialises as a `/nix/store/<hash>-…` path. So "symlink the flake input into the skill dir" means putting a working-tree symlink that points at the store, and every form of that breaks:

- **Committed store symlink.** The store hash is content-addressed, so it **changes on every `nix flake update`** — the committed link goes stale on each bump and must be re-committed. It is also an absolute, machine-specific path: on a fresh clone, a second machine, or after `nix-collect-garbage`, the target may not exist → dangling link → `skill-router` and Home Manager read nothing. "Committed" stops meaning "reproducible".
- **A committed symlink is not a GC root.** Nix only protects store paths reachable from a GC root (a profile generation). A symlink *string* in the repo roots nothing, so garbage collection can delete its target out from under it. A vendored copy is the content itself — it lives in git, not the store — so it can never be GC'd or dangle.
- **Activation-generated symlink into the working tree.** Writing the link at `home.activation` time puts a file *inside the git checkout*: `git status` is then permanently dirty, and it inverts the model — the repo is Nix's **input**, not an output Nix writes into (it would also perturb `lib.cleanSource` hashing of anything that reads the tree).

**The `node_modules` variant (antfu `skills-npm`) fails the same test, harder.** Symlinking from `node_modules/<pkg>/skills` points at a tree that is **not Nix-managed at all** — no flake-lock provenance, no GC-rooting, rebuilt by the npm lifecycle rather than `darwin-rebuild` (the boundary `docs/adr/0006` draws). It self-heals only because a `prepare` script re-runs on `npm install`; nothing on the Nix path guarantees the target exists. That is the right tool for a plain npm app, and the wrong one for a Nix-governed repo.

**Vendoring keeps the skill on the same management plane as the rest of the repo.** A committed copy is plain repo source: Nix reads it, `darwin-rebuild` stays reproducible and offline, generations roll back with it, and it survives GC because it is content in git rather than a pointer into a store the working tree does not root. The one cost — the copy drifts from upstream until re-synced on a flake bump — is acceptable for slow-moving workflow skills, and it is the only option that does not depend on a path Nix's working-tree view cannot durably own.

If upstream-tracking ever outweighs that, the escape hatch is **not** a working-tree symlink: it is a *gitignored* dir (`.agents/skills/`, already a repo-scope dir) that `home.file` regenerates from the store each switch — Nix-rooted, repo-local, and absent from `git status`. That is a deliberate second mechanism, not the default.

## Scope and non-goals

- **Session-injected skills are outside this lever.** `anthropic-skills:*` and `engineering:*` appear in the model's catalog but are not in the local plugin cache (Cowork/cloud session), so `claude.nix` cannot curate them. Document-generation skills (`docx`/`pdf`/`pptx`/`xlsx`) ride that surface and are not addressed here.
- This is about the proactive catalog's *task-fit*, distinct from the per-skill *enabled* vs *discovered* placement (GLOSSARY.md) and from the package-scope command-time trust boundary (`docs/adr/0006`).

## Consequences

- Every repo, including code-dev repos such as `outlook-feishu-bridge`, sees the authoring plugins, the PM skills, and every local skill under `modules/home/skills/`. That is a known catalog cost, accepted so that skill authoring and issue/spec work need no per-repo wiring.
- The plugin dial is all-or-nothing. Turning off `skill-creator` or `claude-md-management` means adding it to `disabledClaudePlugins` and removing its seed `= true` line. A future *multi-purpose* authoring plugin cannot be partially curated.
- Moving a skill off the global catalog is a new decision. It needs a repo-scope mechanism that `modules/home/skills/` does not provide (decision 4), and it should amend this ADR.
