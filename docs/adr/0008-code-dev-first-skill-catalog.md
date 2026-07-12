# Skill catalog is code-dev-first; authoring and project-management skills are repo-scoped

Status: accepted

`skill-router` merges skill scopes by precedence, but what the model sees *without being asked* is the **global proactive catalog**: the Nix agent-skills bundle (`enabledMattpocockSkills` in `modules/home/claude.nix`) plus the enabled Claude Code plugins in `~/.claude/plugins/cache`. That catalog's size is a per-project context cost paid on every session in every repo. The skill-system audit established the shape of that cost: the Nix bundle is cheap (~0.7%) and the **enabled-plugin catalog is the dominant term** — which is why the prior plugin-dial pulls (`context7`, `code-context`, `gitflow`, `git`) targeted plugins, not bundle skills.

This repo's agents work overwhelmingly in **code-dev** repos. Skills whose subject is *authoring skills or agent configuration* are dead weight there — they never fire while writing application code, and they add catalog noise that can mis-trigger. The existing `leanExcludedMattpocockSkills` list already half-codifies this ("signal/noise, not broken"), but only as a long-tail trim. This ADR promotes it to a policy and draws the boundary explicitly.

## Decision

1. **The global proactive catalog is code-dev-first.** Membership is curated by *task-fit*, not by "broken vs working". See CONTEXT.md "Code-dev default catalog".
2. **The boundary is drawn at *authoring* and *project-management*.** Off the global surface: authoring skills (`write-a-skill`, the `skill-creator@claude-plugins-official` and `claude-md-management@claude-plugins-official` plugins) and PM skills (`to-prd`, `to-issues`, `triage`). Design skills (`grill-*`) **stay** — grilling is an active planning workflow that applies in any repo. The issue-tracker workflow the PM skills serve (`CLAUDE.md`, `docs/agents/issue-tracker.md`) lives *in this repo*, so PM skills are not deleted — they are repo-scoped to where the tracker is (mechanism 3) and opt-in for any other repo that gains one.
3. **Two mechanisms, by source:**
   - **Bundle skills worth keeping are repo-scoped as a vendored copy** — dropped from the global bundle (`leanExcludedMattpocockSkills`) and relocated into `nix-config`'s repo scope as a committed `SKILL.md` under `modules/home/skills/` (the `jj` pattern), **never a symlink to the store or to `node_modules`** (see *Why vendored, not symlinked* below), so they surface only here. Applies to `write-a-skill` (authoring) and `to-prd`/`to-issues`/`triage` (PM — `nix-config` owns the issue tracker). Other repos opt in by wiring the same skills into their own repo scope.
   - **Plugin authoring skills are disabled wholesale** via `disabledClaudePlugins`. The plugin dial is all-or-nothing; `skill-creator` and `claude-md-management` are single-purpose authoring plugins, so disabling the whole plugin loses nothing else.

## Why vendored, not symlinked from the store

A repo-scoped skill is a **committed copy** under `modules/home/skills/<name>/` (the `jj` precedent: a real `SKILL.md` in git), not a symlink. The symlink alternatives were considered and rejected because they fail on Nix's own terms.

**Repo scope is discovered from the working tree, but Nix content lives in the store.** `skill-router` finds repo skills by walking `$cwd/modules/home/skills` — the literal git checkout. A flake input (`inputs.mattpocock-skills`) only ever materialises as a `/nix/store/<hash>-…` path. So "symlink the flake input into repo scope" means putting a working-tree symlink that points at the store, and every form of that breaks:

- **Committed store symlink.** The store hash is content-addressed, so it **changes on every `nix flake update`** — the committed link goes stale on each bump and must be re-committed. It is also an absolute, machine-specific path: on a fresh clone, a second machine, or after `nix-collect-garbage`, the target may not exist → dangling link → `skill-router` reads nothing. "Committed" stops meaning "reproducible".
- **A committed symlink is not a GC root.** Nix only protects store paths reachable from a GC root (a profile generation). A symlink *string* in the repo roots nothing, so garbage collection can delete its target out from under it. A vendored copy is the content itself — it lives in git, not the store — so it can never be GC'd or dangle.
- **Activation-generated symlink into the working tree.** Writing the link at `home.activation` time puts a file *inside the git checkout*: `git status` is then permanently dirty, and it inverts the model — the repo is Nix's **input**, not an output Nix writes into (it would also perturb `lib.cleanSource` hashing of anything that reads the tree).

**The `node_modules` variant (antfu `skills-npm`) fails the same test, harder.** Symlinking from `node_modules/<pkg>/skills` points at a tree that is **not Nix-managed at all** — no flake-lock provenance, no GC-rooting, rebuilt by the npm lifecycle rather than `darwin-rebuild` (the boundary `docs/adr/0006` draws). It self-heals only because a `prepare` script re-runs on `npm install`; nothing on the Nix path guarantees the target exists. That is the right tool for a plain npm app, and the wrong one for a Nix-governed repo.

**Vendoring keeps the skill on the same management plane as the rest of the repo.** A committed copy is plain repo source: Nix reads it, `darwin-rebuild` stays reproducible and offline, generations roll back with it, and it survives GC because it is content in git rather than a pointer into a store the working tree does not root. The one cost — the copy drifts from upstream until re-synced on a flake bump — is acceptable for slow-moving workflow skills, and it is the only option that does not depend on a path Nix's working-tree view cannot durably own.

If upstream-tracking ever outweighs that, the escape hatch is **not** a working-tree symlink: it is a *gitignored* dir (`.agents/skills/`, already a repo-scope dir) that `home.file` regenerates from the store each switch — Nix-rooted, repo-local, and absent from `git status`. That is a deliberate second mechanism, not the default.

## Scope and non-goals

- **Session-injected skills are outside this lever.** `anthropic-skills:*` and `engineering:*` appear in the model's catalog but are not in the local plugin cache (Cowork/cloud session), so `claude.nix` cannot curate them. Document-generation skills (`docx`/`pdf`/`pptx`/`xlsx`) ride that surface and are not addressed here.
- This is about the proactive catalog's *task-fit*, distinct from the per-skill *enabled* vs *discovered* placement (CONTEXT.md) and from the package-scope command-time trust boundary (`docs/adr/0006`).

## Consequences

- Code-dev repos (e.g. `outlook-feishu-bridge`) get a catalog without authoring or PM noise; `nix-config` retains `write-a-skill` and the PM skills via repo scope, so skill authoring and issue/PRD work are unimpaired where they actually happen.
- **Re-globalizing an authoring skill** — adding one back to the bundle or enabling an authoring plugin without repo-scoping it — re-crosses this boundary and is a regression, the same way re-adding a removed surface is under ADRs 0002/0005.
- The plugin all-or-nothing constraint means a future *multi-purpose* authoring plugin cannot be partially curated; relocate the wanted skill to repo scope or accept the whole plugin.
- This ADR records the decision; the implementing edits (`leanExcludedMattpocockSkills += "write-a-skill" "to-prd" "to-issues" "triage"`, new vendored repo-scope dirs under `modules/home/skills/`, `disabledClaudePlugins += skill-creator@…`, `claude-md-management@…`) are the follow-up that lands it in `modules/home/claude.nix`.
