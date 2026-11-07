# Shared review and cleanup defaults (issue #367, narrowed scope)

One shared workflow block, existing skills, thin host adapters, honest guards.
Per the 2026-09-17 design review this ships **without** the pipeline engine,
cross-host execution, model-tier mappings, automatic cleanup thresholds, and
the DSPy harness — those were separate projects riding on a routing fix.

Files here are standalone. Nothing is wired into the flake yet; the steps
below are the integration, left for the maintainer.

## What ships

| File | Purpose |
| --- | --- |
| `routing-block.md` | The shared "Review and cleanup" section: defaults table, review procedure, cleanup procedure + contract, posting rule |
| `adapters/codex.md` | One bullet for the Codex adapter (names the tested guard) |
| `adapters/omp.md` | Two bullets for the OMP adapter (review default, guard + its blind spot) |
| `adapters/amp-AGENTS.md` | Thin `~/.config/amp/AGENTS.md`: points at the shared guide, states guidance-only posting |
| `codex/default.rules` | Codex execpolicy posting guard (format and decisions verified live, 2026-09-17) |
| `omp/bash-patterns.json` | OMP `bash.patterns` posting rules (mechanism confirmed from the shipped config schema) |
| `../../tests/unit/review-cleanup-routing-test.nix` | Tier-1 checks (not yet wired into `tests/default.nix`) |
| `../../scripts/verify-review-guards.sh` | Tier-2 live check, run after `just switch` |

## The defaults

Authored once in `routing-block.md` — read them there. One note: the block
never auto-commits to make an uncommitted change reviewable. ADR-0015 decision
4 limits the review host to committed history; that limit belongs to the
skill, not to review as a concept.

## Wiring steps

Prerequisite: the staged guidance consolidation
(`modules/home/agent-instructions*`) lands first, per the issue's own
dependency note.

1. **Render the block into every development guide** — in
   `modules/home/agent-instructions.nix`:

   ```nix
   routingBlock = ./agent-routing/routing-block.md;
   ```

   and change the shared development guide entry plus the two rendered
   development guides to include it last:

   ```nix
   ".config/agent-guidance/development.md" = mkGuide "shared-development.md" [
     sharedDevelopment
     routingBlock
   ];
   ".codex/guidance/development.md" = mkGuide "codex-development.md" [
     ./agent-instructions/codex/guidance/development.md
     sharedDevelopment
     routingBlock
   ];
   ".omp/agent/guidance/development.md" = mkGuide "omp-development.md" [
     ./agent-instructions/omp/agent/guidance/development.md
     sharedDevelopment
     routingBlock
   ];
   ```

   Do the same for the Claude development guide in `claude.nix`
   (`~/.claude/guidance/development.md`).

2. **Codex guard** — add to `files` in `agent-instructions.nix`:

   ```nix
   ".codex/rules/default.rules" = ./agent-routing/codex/default.rules;
   ```

   Append the bullet from `adapters/codex.md` to
   `agent-instructions/codex/AGENTS.md`. In
   `agent-instructions/codex/guidance/development.md`, delete the `**Review**`
   and `**GitHub**` bullets (the block covers them; the Review bullet also
   routes to `calldiff` and `glimpse-changes`, which are not installed
   anywhere — see "Dropped routes" below). In `agent-instructions/codex/
   config.toml`, correct the comment above the rules-file mention: the file
   holds only the two posting rules, not a mirror of Claude's allow/deny lists.

3. **OMP guard** — append the bullets from `adapters/omp.md` to
   `agent-instructions/omp/agent/AGENTS.md`, replacing the existing
   `**Review**` bullet ("Use `reviewer` for substantive changes…"), which sent
   review to the native agent and skipped the review host.

   Reassert the guard at activation like the routing fields. The guard is not
   model routing, so it does not go through the serialized policy; pass the
   JSON file straight to the reconciler. In `modules/home/ai-model-routing.nix`:

   ```nix
   run ${python}/bin/python3 ${./ai-model-routing.py} \
     ${policy} ${config.home.homeDirectory} ${./agent-routing/omp/bash-patterns.json}
   ```

   and in `modules/home/ai-model-routing.py`:

   ```python
   # main(): accept the optional guard file
   guard = json.loads(Path(sys.argv[3]).read_text()) if len(sys.argv) > 3 else {}

   # reconcile_omp_config(home, policy, guard): after the `retry` line
   if guard:
       bash = data.setdefault("bash", {})
       if not isinstance(bash, dict):
           raise TypeError("omp: bash must contain a YAML mapping")
       bash["patterns"] = copy.deepcopy(guard["bash"]["patterns"])
   ```

   Thread `guard` through `apply_policy`. `config.yml` uses nested keys
   (`bash:` / `patterns:`), which is why the JSON file is nested too.

   `bash.patterns` is the right mechanism (confirmed in the shipped config
   schema: "Ordered bash command approval rules. Each item has match and
   approval fields; only '*' wildcards are supported."). `tools.approval` is a
   per-tool record and cannot match command patterns. A matching assertion in
   `tests/unit/ai-model-routing-test.py` (guard survives reconciliation) is a
   natural follow-up.

4. **Amp guide** — add to `files` in `agent-instructions.nix`:

   ```nix
   ".config/amp/AGENTS.md" = ./agent-routing/adapters/amp-AGENTS.md;
   ```

   Amp documents `~/.config/amp/AGENTS.md` as always included. The file points
   at the shared guide instead of embedding the block. That keeps the block
   rendered exactly once, even if Amp also loads `~/AGENTS.md` (unverified —
   see below). Amp needs no guard wiring: no command-scoped guard exists (see
   the honesty table).

5. **Claude adapter** — delete the one-line `**Review**` bullet in
   `modules/home/claude/development.md`; the block covers it.

6. **Tests and recipes** — in `tests/default.nix`:

   ```nix
   unit-review-cleanup-routing = callTest ./unit/review-cleanup-routing-test.nix { };
   ```

   Add `.#checks.aarch64-darwin.unit-review-cleanup-routing` to the `check`
   recipe, and add to the justfile:

   ```make
   # Tier 2: posting guards and guide wiring on the live machine.
   verify-routing: _no-sudo
       bash scripts/verify-review-guards.sh
   ```

7. `just switch`, then `just verify-routing`. Before the wiring the script
   fails on exactly the missing pieces; after, it passes.

## Guard honesty

Three distinct classes — do not conflate them (design review point 3):

| Host | Mechanism | Class | Blind spots |
| --- | --- | --- | --- |
| Codex | `~/.codex/rules/default.rules`, `decision = "prompt"`, fails closed under `approval_policy = "never"` | **Tested command guard** (`codex execpolicy check`, verified 2026-09-17) | `gh api` writes; a prefix rule is argument-order sensitive; non-execpolicy shells |
| OMP | `bash.patterns` rules with `approval: "prompt"` in `config.yml`, reasserted at activation | **Command guard**; the `tools.approvalMode` docs say user policy "may still prompt or block" under `yolo`; one live TUI confirm pending | shells spawned through `eval`; `gh api` writes |
| Amp | none wired | **Guidance only** (`~/.config/amp/AGENTS.md`) | everything; `amp.dangerouslyAllowAll` is on |
| agy | none | **Guidance only** (shared `~/AGENTS.md`) | everything |

Amp facts established 2026-09-17: `amp.permissions` rules are tool-level globs
(`{tool, action: allow|reject|ask|delegate}`) with no command-scoped matching;
an explicit `ask` rule wins over `amp.dangerouslyAllowAll` in
`amp permissions test`, but runtime precedence is unverified and a Bash-wide
`ask` prompts on every shell command — rejected as too broad. Command-scoped
control needs a custom plugin; out of scope here.

## Dropped from the original spec (design review, 2026-09-17)

- Generic step/DAG pipeline engine, `CommandRunner` runtime, code-mode import
  API, cross-host executor choice, budgets/economy flags.
- Codex agent roles and the Amp mode map (new model tiers). The existing OMP
  model policy is kept as-is.
- Automatic cleanup thresholds (300 lines / two top-level dirs). `clean` by
  default; `simplify` only when asked.
- DSPy harness, datasets, optimizer. Keep a few real failure cases instead and
  fix routing manually.
- The guide-loading LLM probe (tests what a model says, not what it does).

## Dropped routes

- `calldiff` and `glimpse-changes`: referenced by the Codex development guide
  but not installed on any host (no binary, no skill dir, no pkgs entry). The
  block reads diff shape with a stat and path-scoped diffs instead. Re-add the
  route when the tools exist.
- The block keeps `hunk diff --watch` (installed) for handing review to the
  user's terminal.

## CONTEXT.md and ADR snippets

Add to CONTEXT.md under "Version control & review":

> **Routing block**:
> The one shared "Review and cleanup" section of the development guide: a
> defaults table (review → `code-review`, open change → `ripwire-change-check`,
> cleanup → `clean`, prose → `unslop`, native reviewers named-only), the review
> and cleanup procedures, and the posting rule. Authored once in
> `modules/home/agent-routing/routing-block.md`, rendered into every
> development guide.
> _Avoid_: a second copy in any adapter; routing to uninstalled tools.

Amend the **Review host** entry: "Routing lives in the Git section of
CLAUDE.md" becomes "Routing lives in the routing block".

Amend ADR-0015 (append):

> Amendment (2026-09-17, issue #367): decision 3's location moves from the Git
> section of CLAUDE.md to the shared routing block, rendered into every host's
> development guide. Decisions 1, 2, 4, and 5 stand. Cleanup defaults joined
> review routing in the same block. Posting guards landed per host: Codex
> execpolicy prefix rules (tested), OMP `bash.patterns` (schema-confirmed),
> Amp guidance-only.

## Unverified, check by hand once

1. Whether Amp and agy actually load `~/AGENTS.md` (the block reaches them via
   the Develop pointer either way; `~/.config/amp/AGENTS.md` is documented as
   always included).
2. OMP `approval: "prompt"` interrupting a `gh pr comment` under
   `tools.approvalMode = yolo`. The `omp config get tools.approvalMode`
   description says user policy "may still prompt or block" under yolo, so a
   prompt is expected; confirm once by hand in the TUI.
3. The `eval`-spawned shell blind spot on OMP (would need
   `tools.approval.eval`; deferred).
