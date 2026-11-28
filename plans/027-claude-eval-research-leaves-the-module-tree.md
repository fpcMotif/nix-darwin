# Plan 027: The Claude eval research scripts leave the Home Manager module tree

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5442cca..HEAD -- modules/home/claude/evals modules/home/claude/shell-guard-eval.md`
> If any of these changed, compare the "Current state" excerpts against the
> live files. On a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `5442cca`, 2026-11-27

## At a glance

`modules/home/claude/` holds five Python research scripts, a baseline JSON
file, and the write-up that cites them, and nothing in the flake imports,
installs, or tests any of them. This plan moves them to `tools/claude-evals/`
and repairs the two paths that depend on their location. Every installed file
stays unchanged.

## Why this matters

`modules/home/claude/` is the directory that defines what gets installed into
`~/.claude`. Six files there are hand-run research, about 1,100 lines, so a
reader who asks "what does this directory deploy" has to read them to find out
the answer is "not these". Hand-run tools belong in `tools/`.

## Current state

The files, all under `modules/home/claude/`:

- `evals/edit-batching-census.py`
- `evals/edit-tool-census.py`
- `evals/hook-census.py`
- `evals/hook-census-baseline.json`
- `evals/search-routing-trial.py`
- `evals/shell-guard-trial.py`
- `shell-guard-eval.md` (the write-up)

Nothing in the flake reads them. On 2026-11-27 this command printed only
lines inside `modules/home/claude/shell-guard-eval.md`:

```bash
rg -n 'claude/evals|shell-guard-eval' --glob '!plans/**' --glob '!references/**' --glob '!modules/home/claude/evals/**' .
```

Two scripts depend on where they sit:

- `evals/shell-guard-trial.py:30-31` loads a sibling script:

  ```python
  HERE = Path(__file__).resolve().parent
  _spec = importlib.util.spec_from_file_location("census", HERE / "edit-tool-census.py")
  ```

  The sibling moves with it, so this keeps working.

- `evals/search-routing-trial.py:23-24` reads a file one directory up:

  ```python
  HERE = Path(__file__).resolve().parent
  CLAUDE_ADAPTER = HERE.parent / "claude-adapter.md"
  ```

  `modules/home/claude/claude-adapter.md` does not move. After the move this
  path would point at `tools/claude-adapter.md`, which does not exist.

The write-up names the scripts in four places, `shell-guard-eval.md`:

- line 31: ``## Census of real transcripts (`evals/edit-tool-census.py`)``
- line 60: ``## Two-arm trial (`evals/shell-guard-trial.py`)``
- line 81: ``## Edit batching (`evals/edit-batching-census.py`)``
- line 100: ``Rerun: `uv run modules/home/claude/evals/shell-guard-trial.py --steer-bash --runs 2 --model sonnet --out /tmp/trial.json` ...``

A file that looks related and is NOT part of this: `modules/home/claude/search-eval.md`.
It is installed. `modules/home/agent-instructions/guides.nix:124` links it to
`~/.claude/search-eval.md`, and
`tests/integration/configurations-eval/home.nix:332` asserts that. It stays.

Repo rules that apply:

- A `doc-lock` hook blocks Markdown and comment changes outside docs work.
  This plan moves one Markdown file and edits four lines in it. If the hook
  blocks an edit, stop and report. The operator then opens docs work.
- Run Python with `uv run`. Agent shells here deny bare `python`, and also
  `cd`, `sed`, and `find`. Run every command from the repo root.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| Invariance | `nix eval --raw '.#darwinConfigurations.f.config.home-manager.users.martinfan.home.activationPackage.drvPath'` | prints one `.drv` path |
| Syntax | `uv run python -c "import ast, sys; [ast.parse(open(f).read(), f) for f in sys.argv[1:]]" tools/claude-evals/*.py` | exit 0, no output |
| Home checks | `nix build --no-link '.#checks.aarch64-darwin.integration-configurations-eval'` | exit 0 |

## Scope

**In scope** (the only files you may modify):

- `modules/home/claude/evals/` (move all six files to `tools/claude-evals/`)
- `modules/home/claude/shell-guard-eval.md` (move to `tools/claude-evals/shell-guard-eval.md`, then edit lines 31, 60, 81, 100)
- `tools/claude-evals/search-routing-trial.py` (line 24 only, after the move)

**Out of scope** (do NOT touch):

- `modules/home/claude/search-eval.md`, `search-routing.md`, and
  `claude-adapter.md`. They are installed guides.
- `modules/home/claude/mods/`. The two test files there are a separate
  question. See "Maintenance notes".
- The logic of any Python script.
- The docstring at `search-routing-trial.py:10`, which names
  `modules/home/claude/claude-adapter.md`. That path stays correct.

## Git workflow

- Branch: `advisor/027-claude-eval-research-leaves-the-module-tree`.
- One commit: `refactor(evals): move the Claude eval research scripts to tools/claude-evals`
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Record the baseline and confirm nothing reads the files

Run the Invariance command and save its output as `BEFORE`.

Run the `rg` command shown under "Current state".

**Verify**: every line it prints is inside
`modules/home/claude/shell-guard-eval.md`. Any other file is a STOP condition.

### Step 2: Move the files

1. `mkdir -p tools/claude-evals`
2. `git mv` each of the six files in `modules/home/claude/evals/` to
   `tools/claude-evals/`, keeping its name. One command per file.
3. `git mv modules/home/claude/shell-guard-eval.md tools/claude-evals/shell-guard-eval.md`
4. Run `ls -A modules/home/claude/evals`. If it lists only `.ruff_cache`,
   an untracked lint cache, delete the directory with
   `rm -r modules/home/claude/evals`. If it lists anything else, STOP and
   report. If it lists nothing, run `rmdir modules/home/claude/evals`.

**Verify**: `test ! -e modules/home/claude/evals && test ! -e modules/home/claude/shell-guard-eval.md` exits 0.
`ls tools/claude-evals` lists seven files.

### Step 3: Repair the adapter path

In `tools/claude-evals/search-routing-trial.py`, change line 24 to:

```python
CLAUDE_ADAPTER = HERE.parents[1] / "modules" / "home" / "claude" / "claude-adapter.md"
```

`HERE` is `tools/claude-evals`, so `HERE.parents[1]` is the repo root.

**Verify**: the Syntax command exits 0. Then run:

```bash
uv run python -c "import pathlib; h = pathlib.Path('tools/claude-evals').resolve(); p = h.parents[1] / 'modules' / 'home' / 'claude' / 'claude-adapter.md'; print(p.is_file())"
```

It prints `True`.

### Step 4: Repair the write-up

In `tools/claude-evals/shell-guard-eval.md`:

1. Line 31: change `` `evals/edit-tool-census.py` `` to `` `edit-tool-census.py` ``.
2. Line 60: change `` `evals/shell-guard-trial.py` `` to `` `shell-guard-trial.py` ``.
3. Line 81: change `` `evals/edit-batching-census.py` `` to `` `edit-batching-census.py` ``.
4. Line 100 names two scripts. Change every
   `modules/home/claude/evals/` on that line to `tools/claude-evals/`. That
   covers `shell-guard-trial.py` and `edit-tool-census.py`.

**Verify**: `rg -n 'evals/|modules/home/claude/evals' tools/claude-evals/shell-guard-eval.md`
prints nothing.

### Step 5: Check that nothing installed changed

Run the Invariance command.

**Verify**: the output equals `BEFORE` exactly. The Home checks command exits 0.
Commit.

## Test plan

- No new test. Nothing in the flake reads these files, and the invariance
  check proves it.
- Step 3 checks the one path that the move would have broken.
- The scripts call the Claude CLI and read real transcripts, so they are not
  run here. The Syntax command checks they still parse, and writes no cache files.

## Done criteria

- [ ] `test ! -e modules/home/claude/evals` exits 0
- [ ] `ls tools/claude-evals | wc -l` prints `7`
- [ ] `rg -n 'claude/evals' --glob '!plans/**' --glob '!references/**' .` returns no matches
- [ ] `uv run python -c "import ast, sys; [ast.parse(open(f).read(), f) for f in sys.argv[1:]]" tools/claude-evals/*.py` exits 0
- [ ] The Step 5 invariance check passed
- [ ] `git status --short` lists only in-scope paths (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- A file outside `shell-guard-eval.md` references `claude/evals` or
  `shell-guard-eval`.
- A script in `evals/` uses `HERE` or `__file__` in a way this plan does not
  list. Check with `rg -n 'HERE|__file__' modules/home/claude/evals` before
  Step 2. On 2026-11-27 it printed four lines: lines 30-31 of
  `shell-guard-trial.py` and lines 23-24 of `search-routing-trial.py`.
- The Step 5 invariance check fails.
- The `doc-lock` hook blocks an edit.

## Maintenance notes

- Open question for the maintainer, not decided here:
  `modules/home/claude/mods/jev-report/tests/jev-report.test.tsx` and
  `modules/home/claude/mods/jev-traits/tests/jev-traits.test.ts` import
  `claude-code/testing`. No check, recipe, or hook in this repo runs them, and
  `modules/home/claude.nix:520-521` copies both mod directories, tests
  included, into `~/.claude/mods`. They may be run by Claude Code's own mod
  tooling. If they are hand-run, `tests/README.md` should say so.
- `search-eval.md` calibrates numbers that `shell-guard-eval.md` cites. The
  two files now live in different directories. That is intended: one is an
  installed guide and the other is a research note.
