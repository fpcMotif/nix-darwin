# Plan 012: Remove stale root files and the pstack exports nothing reads

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 534fc39..HEAD -- modules/home/claude/pstack.nix modules/home/claude.nix tests/unit/pstack-hygiene-test.nix docs/adr/0014-pstack-is-transformed-nix-skills-reuse-first.md`
> If `pstack.nix` changed, compare the "Current state" excerpts against the
> live code. On a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `534fc39`, 2026-11-17

## At a glance

Two tracked files at the repo root are stale and referenced by nothing.
`modules/home/claude/pstack.nix` exports three values that no caller reads,
and takes two arguments only to build them. This plan deletes those, fixes one
wrong path in generated text, and corrects one ADR clause. The pstack skills
that get installed are byte-for-byte unchanged.

## Why this matters

`AGENT_SKILLS_NIX_REPORT.md` opens with a banner saying the current code
supersedes it. A reader or an agent that finds it first follows an old design.
The dead pstack exports make a 233-line transform look like it feeds a second
install path that was removed. ADR-0014 still describes that removed path.

## Current state

### Root files

- `AGENT_SKILLS_NIX_REPORT.md` — tracked. Lines 3-8 are a "current
  implementation supersedes the analysis below" banner.
- `autoresearch.jsonl` — tracked, about 87 KB of benchmark run logs.
  `.gitignore:21` ignores only `/autoresearch.config.json`.
- `outputs/` — untracked. Holds one empty directory, `outputs/out`.

`rg -l 'AGENT_SKILLS_NIX_REPORT|autoresearch\.jsonl' --glob '!references/**' --glob '!plans/**' .`
printed nothing on 2026-11-17. No file refers to either.

### pstack exports

`modules/home/claude/pstack.nix:1`:

```nix
{ lib, pkgs, inputs, mkSource, mkSkill, docLock ? true }:
```

`modules/home/claude/pstack.nix:180-190` today:

```nix
  pstackSources = {
    pstack = mkSource "pstack-claude" "plugins/pstack/skills"
      "^(${lib.concatStringsSep "|" pstackSkills})$";
  };
  pstackExplicit = lib.listToAttrs
    (map
      (id: { name = id; value = mkSkill "pstack" id [ ] // { transform = pstackTransform id; }; })
      pstackSkills) // {
    pstack-principles = mkSkill "pstack" "principle-laziness-protocol" [ ]
      // { transform = _: pstackPrinciplesSkill; };
  };
```

`modules/home/claude/pstack.nix:227-233` today:

```nix
  pstackAgentFile = name: pkgs.writeText name (pstackAgentText name);
in
{
  inherit pstackSkillsRoot pstackPrinciples pstackSkills pstackAliases
    pstackTransform pstackPrinciplesSkill pstackModelRoles pstackModelsSheetText
    pstackModelsSheet pstackSources pstackExplicit pstackDrvs pstackAgentText pstackAgentFile;
}
```

The two callers:

- `modules/home/claude.nix:352-356`:

  ```nix
  pstack = import ./claude/pstack.nix {
    inherit lib pkgs inputs mkSource mkSkill;
    inherit (config.martin.development) docLock;
  };
  inherit (pstack) pstackModelsSheet pstackDrvs;
  ```

- `tests/unit/pstack-hygiene-test.nix:11`:

  ```nix
  pstack = import (self + "/modules/home/claude/pstack.nix") { inherit lib pkgs inputs mkSource mkSkill; };
  ```

  The test reads `pstack.pstackTransform`, `pstack.pstackPrinciplesSkill`,
  `pstack.pstackAgentText`, and `pstack.pstackModelsSheetText`.

So `pstackSources`, `pstackExplicit`, and `pstackAgentFile` have no reader.
`mkSource` and `mkSkill` are used only by the first two.

`mkSource` and `mkSkill` are still used elsewhere in `modules/home/claude.nix`
(for `mpSources`, `effectSources`, and `programs.agent-skills`). Keep their
definitions there.

### Wrong path in generated text

`modules/home/claude/pstack.nix:175`, inside the string `pstackModelsSheetText`:

```text
    Nix-owned: modules/home/claude.nix, pstackModelRoles. One line per pstack role; ...
```

`pstackModelRoles` is defined in `modules/home/claude/pstack.nix:155`, not in `claude.nix`.

### Stale ADR clause

`docs/adr/0014-pstack-is-transformed-nix-skills-reuse-first.md:19`, item 7, starts:

```markdown
7. **Subagent**: `poteto-agent` is installed under `~/.claude/agents` from the input through a `writeText` that rewrites its description ...
```

No `home.file` entry installs anything under `.claude/agents` today.
`rg -n 'claude/agents' modules/home/claude.nix` prints nothing. The agent now
comes from the pstack plugin, enabled at `modules/home/claude.nix:91`
(`pstackPluginId = "pstack@cursor-plugins";`).

Repo rules that apply:

- A `doc-lock` hook blocks new or changed code comments and Markdown outside
  docs work. This plan edits one ADR. If the hook blocks it, stop and report.
- ADRs describe the current state. Rewrite the clause in place. Do not add a
  "superseded" note or an update section.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| Invariance | `nix eval --raw '.#darwinConfigurations.f.config.home-manager.users.martinfan.home.activationPackage.drvPath'` | prints one `/nix/store/...drv` path |
| pstack test | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-pstack-hygiene'` | exit 0 |
| Skill test | `nix build --no-link '.#checks.aarch64-darwin.unit-skill-hygiene'` | exit 0 |
| ADR shape | `bash tests/unit/adr-files-test.sh docs/adr && bash tests/unit/adr-numbers-test.sh docs/adr` | exit 0 |
| Lint | `nix develop --command deadnix --fail modules/home/claude/pstack.nix` | exit 0 |
| Format | `nix fmt -- --check modules/home/claude/pstack.nix modules/home/claude.nix tests/unit/pstack-hygiene-test.nix` | exit 0 |

## Scope

**In scope** (the only files you may modify):

- `AGENT_SKILLS_NIX_REPORT.md` (delete)
- `autoresearch.jsonl` (delete)
- `outputs/` (remove the empty untracked directory)
- `modules/home/claude/pstack.nix`
- `modules/home/claude.nix` (line 353 only)
- `tests/unit/pstack-hygiene-test.nix` (line 11, and any now-unused binding it leaves)
- `docs/adr/0014-pstack-is-transformed-nix-skills-reuse-first.md` (item 7 only)

**Out of scope** (do NOT touch):

- `scripts/setup-varlock-env.sh`. Nothing references it, but it is a
  hand-run utility for other projects. Leave it.
- `references/`. It is documented in `ARCHITECTURE.md` and kept on purpose.
- `pstackTransform` and its replacement lists. Do not change any rewrite rule.
- `pstackAgentText`. The test reads it.
- `PANIC.md`, `HOTKEYS.md`, `config/omp/`. All are referenced.

## Git workflow

- Branch: `advisor/012-remove-root-leftovers-and-dead-pstack-exports`.
- Two commits:
  1. `chore: delete the superseded skills report and the autoresearch log`
  2. `refactor(pstack): drop exports and arguments nothing reads`
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Record the baseline

Run the Invariance command and save its output as `BEFORE`.

### Step 2: Delete the root leftovers

Run `git rm AGENT_SKILLS_NIX_REPORT.md autoresearch.jsonl`. Then remove the
empty directories with `rmdir outputs/out outputs`.

**Verify**: `test ! -e AGENT_SKILLS_NIX_REPORT.md && test ! -e autoresearch.jsonl && test ! -e outputs` exits 0.
`nix build --no-link '.#checks.aarch64-darwin.unit-doc-links'` exits 0.

Commit (commit 1).

### Step 3: Remove the dead pstack code

In `modules/home/claude/pstack.nix`:

1. Change line 1 to `{ lib, pkgs, inputs, docLock ? true }:`.
2. Delete the `pstackSources = { ... };` and `pstackExplicit = ... ;` bindings
   (lines 180-190).
3. Delete the line `pstackAgentFile = name: pkgs.writeText name (pstackAgentText name);`.
4. In the final `inherit`, remove the three names `pstackSources`,
   `pstackExplicit`, and `pstackAgentFile`. Keep every other name.
5. In the string at line 175, change `modules/home/claude.nix, pstackModelRoles`
   to `modules/home/claude/pstack.nix, pstackModelRoles`.

In `modules/home/claude.nix`, change line 353 from
`inherit lib pkgs inputs mkSource mkSkill;` to `inherit lib pkgs inputs;`.

In `tests/unit/pstack-hygiene-test.nix`, change line 11 so the import passes
`{ inherit lib pkgs inputs; }`. Then check whether `mkSource` and `mkSkill`
are still used in that file with `rg -n 'mkSource|mkSkill' tests/unit/pstack-hygiene-test.nix`.
If their only remaining uses are their own definitions, delete those definitions.

**Verify**: `nix develop --command deadnix --fail modules/home/claude/pstack.nix tests/unit/pstack-hygiene-test.nix` exits 0.
`nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-pstack-hygiene'` exits 0.

### Step 4: Check the one intended output change

Step 3 item 5 changes one sentence in `~/.claude/pstack-models.md`. Nothing
else may change.

Run the Invariance command and save its output as `AFTER`.

**Verify**: `AFTER` differs from `BEFORE` (the sheet text changed). Then
temporarily revert item 5 only, run the Invariance command again, and confirm
the output equals `BEFORE` exactly. Re-apply item 5.

If the output with item 5 reverted does not equal `BEFORE`, something else
changed. That is a STOP condition.

### Step 5: Correct ADR-0014 item 7

In `docs/adr/0014-pstack-is-transformed-nix-skills-reuse-first.md`, rewrite
the first sentence of item 7 to state the current behaviour: the
`poteto-agent` subagent is supplied by the `pstack@cursor-plugins` plugin, and
Nix installs nothing under `~/.claude/agents`. Keep the rest of item 7 only
where it is still true. `pstackAgentText` still exists and is used by
`tests/unit/pstack-hygiene-test.nix` to check the description rewrite.

**Verify**: `rg -n 'installed under .~/.claude/agents' docs/adr/0014-pstack-is-transformed-nix-skills-reuse-first.md` prints nothing.
`bash tests/unit/adr-files-test.sh docs/adr && bash tests/unit/adr-numbers-test.sh docs/adr` exits 0.

Commit (commit 2).

## Test plan

- No new test. The gate is build invariance: with the one-sentence text fix
  reverted, the Home Manager activation package has the same derivation path
  as before. That proves no installed file changed.
- `unit-pstack-hygiene` keeps covering the transform.

## Done criteria

- [ ] `rg -n 'pstackSources|pstackExplicit|pstackAgentFile' --glob '!plans/**' --glob '!references/**' .` returns no matches
- [ ] `nix build --no-link '.#checks.aarch64-darwin.unit-pstack-hygiene'` exits 0
- [ ] `nix build --no-link '.#checks.aarch64-darwin.unit-skill-hygiene'` exits 0
- [ ] `nix fmt -- --check modules/home/claude/pstack.nix modules/home/claude.nix tests/unit/pstack-hygiene-test.nix` exits 0
- [ ] The Step 4 invariance check passed
- [ ] `git status --short` lists only in-scope paths (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Any file outside `plans/` and `references/` references
  `AGENT_SKILLS_NIX_REPORT` or `autoresearch.jsonl`.
- `rg -n 'pstackSources|pstackExplicit|pstackAgentFile'` finds a reader outside
  `modules/home/claude/pstack.nix`.
- `outputs/` holds any file. Do not delete non-empty directories.
- The Step 4 invariance check fails.
- The `doc-lock` hook blocks the ADR edit.

## Maintenance notes

- `tests/unit/skill-hygiene-test.nix:22` reads `modules/home/claude.nix` as
  text. Plan 017 also edits `claude.nix`. Land this plan first, or rebase.
- Observation left for the maintainer: the transform at
  `modules/home/claude/pstack.nix:96-97` writes "The agent lives in
  `~/.claude/agents`, so the bare name resolves." into skills that non-Claude
  agents also receive. With the agent now supplied by the plugin, that
  sentence may be wrong. Changing it alters installed skill text, so it is
  not part of this plan.
