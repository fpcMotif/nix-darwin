# Skill loading favors a cold catalog and on-demand load over eager fan-out

Status: proposed

This ADR records the direction reached after verifying the current agent-skill
setup against the "best engineered way to load agent skills" — TanStack Intent's
package-artifact, on-demand model, plus Matt Pocock's strict small-skill
authoring discipline. It supersedes the "link everything into every target"
framing of `AGENT_SKILLS_NIX_REPORT.md`; it does **not** contradict
`docs/adr/0003-scope-code-context-mcp-per-project.md` — it extends the same
lean-catalog goal from MCP servers to skills. Implementation is deferred to a
follow-up; nothing in `modules/home/claude.nix` changes as part of this ADR.

## What we actually do today (verified)

`programs.agent-skills` (`modules/home/claude.nix:580-612`) builds one immutable
`/nix/store` bundle and `link`s it into **five** picker target dirs — `.agents`,
`.claude`, `.cursor`, `.codex`, `.pi/agent` (all `+/skills`), from the single
`skillTargetDirs` set (`claude.nix:154-160, 149, 609`). Verified specifics:

- All five targets use `structure = "link"`; `excludePatterns = [ ]`
  (`claude.nix:611`) is set but **inert** — the `link` path bypasses the rsync
  code entirely. `.codex/skills` is a literal byte-for-byte duplicate of
  `.agents/skills`.
- Curation is eval-time-first: `enabledMattpocockSkills` is a `readDir` of the
  three buckets minus three blocklists — `disabledMattpocockSkills`,
  `transformedMattpocockSkills`, and `leanExcludedMattpocockSkills`
  (`claude.nix:252-267`). A **lean-excluded skill leaves the bundle entirely**;
  recovering it needs a Nix edit + rebuild.
- Eight `home.activation` blocks; seven mutate state **outside** `/nix/store`
  (Claude Desktop sessions, plugin caches, `settings.json`, the Surge.app
  bundle) to prune/park/dedup. This is the per-app glue tax.
- The one locally-authored skill, `modules/home/skills/jj/SKILL.md`, is 121
  lines and ships no `references/` — over Matt Pocock's <100-line target.

This is a careful Nix implementation of the *symlink-bundling fallback* the
standard relegates to a compatibility escape hatch, not its primary model.

## The honest gap (and a correction)

The headline objection — "eager fan-out injects every skill body at startup" —
is overstated for agents that implement native progressive disclosure. Claude
Code loads only each skill's frontmatter (name + description) into context at
session start and the full `SKILL.md` body only on activation. So eager-on-*disk*
is not full-bodies-in-*context*; the real startup cost is the **catalog size =
number of skills sitting in the target dir**, which curation already bounds.

That sharpens the real gaps rather than removing them:

1. **The cold tail is not loadable.** Native disclosure still scales the catalog
   with dir count, so the only lever to keep the catalog small is *deleting*
   skills from the bundle. There is no "keep many skills installed-but-cold,
   surface a curated subset, load the rest by id." This is exactly the
   `Discovered` vs `Enabled` split `CONTEXT.md` already defines — but today both
   states resolve to files-on-disk, so "discovered but not enabled" is only
   achievable by deletion.
2. **No validation or trust gate** before third-party prompt text auto-lands in
   five dirs. `enableAll` + bucket auto-discovery mean a new upstream skill ships
   to every agent on the next `nix flake update`, unreviewed.
3. **Fan-out glue is a standing maintenance/safety cost** independent of context
   budget: the sweeps couple us to each app's internal session/plugin-cache
   layout, and the out-of-store `rm -rf`/`mv`/`jq`-rewrite blocks carry
   race and partial-activation hazards.

## What TanStack Intent contributes, and the impedance wall

Intent's `list` / `install` / `stale` / registry are all built on the **npm
dependency graph** (node_modules / Yarn PnP / npm-registry version compare /
`tanstack-intent`-keyword tarball indexing). Our skill sources are `flake = false`
git inputs in `/nix/store` — **none are npm packages** — so that machinery does
not function here, and it is redundant: `flake.lock` already is our
version-alignment engine. What transfers cleanly is the **loading model**
(thin catalog → `load <id>` one body on demand) and **`validate`**, which lints
a raw directory with no npm context.

Bun is already the backbone (`bunx → bun`; `zsh.nix:217-220` routes
`npm/npx/pnpm` through bun/bunx), and the repo already rejected the
runtime-installer pattern: `claude.nix:324` replaced `bunx skills add` with a
flake input "so Nix stays the single source of truth — no runtime mutation," and
`claude.nix:224` disables `setup-matt-pocock-skills` as a "runtime installer that
fights this Nix-managed setup." The correct `bunx` role is therefore the
**substrate-free subset only**: `bunx @tanstack/intent@latest validate <dir>` as
a CI gate, and `scaffold` / `meta` for authoring. Not `bunx skills add` (runtime
mutation, already rejected) and not `bunx intent list/load` (needs a JS
workspace it cannot find under `/nix/store`).

## Decision

Keep Nix as the skill **transport and version-alignment engine** (unchanged),
and adopt Intent's **loading model** on top of it, making the `Discovered` vs
`Enabled` distinction `CONTEXT.md` already names mechanically real:

- **Cold, not deleted.** Long-tail / lean-excluded skills stay in the bundle but
  out of the link targets — `Discovered` (loadable) yet absent from any agent's
  native catalog. Curation stops meaning "delete" and starts meaning "cold."
- **A Nix-native loader.** Ship a small `skill-load <source>#<skill>` that `cat`s
  `$BUNDLE/<source>/<skill>/SKILL.md` from the store — our `intent load`.
  Because the store path is content-addressed and lock-pinned, it already loads
  the exact version in use. Optionally expose it as a slash command so the cold
  tail is recoverable without a rebuild.
- **An authoring gate.** Run `bunx @tanstack/intent@latest validate` over the
  sources as a flake check, layered with a stricter ≤100-line + description-length
  rule (Intent's 500-line ceiling is the outer guardrail; Pocock's 100 is the
  budget). This gates the unreviewed auto-discovery pipe and flags `jj` (121
  lines) today.

The single highest-leverage change is the cold-in-bundle + `skill-load` pair: it
imports Intent's whole value (cold-loadable long tail, ~1% context budget,
load-the-version-you-have) onto the Nix substrate without any npm-coupled
machinery, as a small additive change rather than a rewrite of the fan-out.

## Considered options

- **Adopt TanStack Intent wholesale (bun workspace / republish skills to npm).**
  Rejected: re-imports the npm substrate Nix exists to avoid; `list`/`stale`/
  registry duplicate what `flake.lock` already does for git sources.
- **Keep curation-by-deletion; just hand-trim the blocklist as sources grow.**
  Rejected: the long tail stays unrecoverable without a rebuild, and the
  blocklist is a static cap that must be re-curated forever — a token-budget
  band-aid, not progressive disclosure.
- **Rip out the 5-dir fan-out and the activation glue.** Rejected for now: the
  fan-out is defensible while each agent needs its native dir, and native
  progressive disclosure already keeps the *Enabled* subset cheap. The glue tax
  is real but a separate axis; trimming it is a follow-up, not this decision.
- **Cold-in-bundle + `skill-load` loader + `validate` gate, Nix as transport**
  (chosen): smallest change that makes `Discovered` vs `Enabled` real, keeps the
  reproducibility/lockfile/rollback wins, and uses `bunx` only where it works
  without a dependency graph.

## Consequences

- `excludePatterns` / curation gain a real meaning: cold skills remain in the
  store bundle and are reachable via `skill-load`, instead of being dropped from
  the bundle. `leanExcludedMattpocockSkills` becomes a "cold" list, not a delete
  list.
- A new artifact to maintain: the `skill-load` command (and, if exposed, a
  per-agent slash command). It must read from the same derivation that builds the
  bundle so the catalog and bodies cannot drift.
- CI gains a `bunx @tanstack/intent@latest validate` step plus a ≤100-line lint;
  the `jj` skill must be split (move revsets + rebase/recovery into
  `references/`) to pass, modelling the one-level-deep reference discipline.
- Pin `@tanstack/intent` to a version in CI rather than `@latest` (it is pre-1.0,
  v0.0.41); a flag rename should not wedge the rebuild — same posture as the
  vendored-CLI pinning noted in `CONTEXT.md`.
- Cloud/sandbox caveat: this loading model is user-level (Home-Manager dirs, a
  global `skill-load`). A fresh clone has none of it; if sandbox agents must see
  skills, expose the bundle + loader as a flake/devshell output the sandbox can
  `nix build`.
- Trust posture improves: a catalog that lists skills without auto-injecting
  bodies means untrusted third-party text enters context only on an explicit
  load. Keep the existing allowlist/park filtering; do not `enableAll` public
  sources.
- No behavior changes land with this ADR; it records the direction. The
  cold-loader + validate-gate implementation is a separate follow-up PR.
