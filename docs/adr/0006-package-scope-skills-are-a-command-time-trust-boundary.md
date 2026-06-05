# Package-scope skills are a command-time trust boundary, not Nix-governed

Status: accepted

`skill-router` (`modules/home/skill-router.nix`, `tools/skill-router`) merges four skill scopes by precedence: `repo > workspace > user > package`. The first three resolve to files on disk — the `user` scope is the Nix-built agent-skills bundle, `repo`/`workspace` are checked-in `SKILL.md` files. The `package` scope is different in kind: it is TanStack Intent, invoked as `bunx @tanstack/intent <version> list/load`, which downloads and executes registry JavaScript at command time to surface skills shipped inside installed npm packages.

That last scope sits outside everything Nix guarantees for the rest of this repo (see `ARCHITECTURE.md`: pure-Nix-first, reproducible, no runtime mutation). We accept it anyway, as a consciously bounded exception — the same move ADR 0005 makes for Dropbox — and this ADR records the boundary so it is governed by documentation rather than left implicit.

## Why the package scope cannot be Nix-governed

- **It is npm-registry JS executed at command time.** `bunx @tanstack/intent@<v>` resolves and runs a dependency tree fetched from the registry. Pinning the runner (`@0.0.41`, not `@latest`) buys *version-stability on a warm bun cache* — it does **not** buy flake-lock provenance, content-addressing, GC-rooting, or offline determinism. The bytes Intent runs live in `~/.bun/install/cache`, which no `darwin-rebuild`, `nix flake update`, or generation rollback governs. Verified: with `@0.0.41` pinned, `intent list` succeeds offline from a warm cache but `@latest` fails offline with `ConnectionRefused`.
- **The consumer ecosystem is empty for us today.** No repo here depends on any `@tanstack/*` package, and `bunx @tanstack/intent@0.0.41 list` returns "No intent-enabled packages found." in every real repo. Paying a provenance/vendoring cost now would buy a capability with zero current consumers — the same dead-weight test that removed gemini-cli (ADR 0002) and the Dropbox scaffold (ADR 0005).

## The contract

1. **Two trust boundaries.** Nix owns provenance, offline-determinism, and GC for the `repo`/`workspace`/`user` scopes. The `package` scope is a best-effort, command-time, user-initiated convenience that is **allowed to no-op offline** and is **never on the rebuild path**.
2. **Never at build or activation time.** `skill-router.nix` only adds the CLI to `home.packages` and symlinks a static `config.json`; it performs no `home.activation`/build-time `bunx` call. So `darwin-rebuild switch` and `nix build` never reach the network on its behalf — offline rebuilds are unaffected.
3. **Opt-in and dormant by default.** `config.catalog.packageScope` defaults to `false`; `skill-router discover` is local-only (~100ms) until a caller passes `--package` (which spawns the pinned Intent runner, ~1s). `discoverIntentSkills` returns `[]` on any non-zero exit or parse failure, so offline / missing-network degrades to a graceful empty result, never a hard error.
4. **Pinning is version-stability, not reproducibility.** `intentRunner` is pinned for stability and to stop `@latest` re-resolving on every call; it is not claimed to make the scope reproducible. Bump it deliberately, like any other pin.

## Why not vendor Intent for full parity

A fixed-output derivation that pre-populates the Intent tarball into the bun cache (or a `--prefer-offline` flake-pinned cache dir) would give the package scope flake-tracked provenance. We reject that today purely on cost: at zero consumers it is machinery for no payoff. Revisit only when `intent list` first returns a non-empty result in a real repo — i.e. when a depended-on library actually ships `skills/**/SKILL.md`.

## Consequences

- The pinned runner + `packageScope: false` default live in `tools/skill-router/config.default.json`; `discover.ts` reads the config default and honours the `--package` / `--no-package` overrides. `catalog`, `install-agents`, and local `load scope:id` stay local-only unless the user explicitly requests package scope (`catalog --package`) or loads a package ID (`load @pkg#skill`).
- Anything on the rebuild path (an activation script, a build input) that depends on the package scope is a regression — as is flipping `packageScope` to `true` by default or wiring an activation-time `bunx intent` call. Those re-cross the boundary this ADR draws.
- Per-project adoption, when a library ships intent skills, is a writable-`AGENTS.md` edit in that repo (`bunx @tanstack/intent@0.0.41 install`, never `--map`), not a change to the Nix-governed global config.
