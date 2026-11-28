# Plan 031: Maintained docs name paths that exist, and a check keeps it so

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5442cca..HEAD -- GLOSSARY.md AGENTS.md tests/README.md tests/default.nix docs/adr/0008-reproducible-dev-envs-and-cross-platform-purity.md docs/adr/0016-mbx-is-mise-managed-not-nix-managed.md`
> Drift is expected here. A large docs rewrite was in progress in the working
> tree when this plan was written, and plans 024, 025, 029, and 030 move
> files. This plan finds every edit by its text, never by a line number. The
> line numbers below are a hint only.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: plans 024, 025, 029, 030 (soft: see "Order")
- **Category**: docs
- **Planned at**: commit `5442cca`, 2026-11-27

## At a glance

Up to seven places in maintained docs and skills name `modules/home/zsh.nix`, a file
that moved to `modules/home/shell/`, and two rows of the checks table describe
commands the checks do not run. Nothing tests that a path written in a doc
exists, so each file move leaves stale text behind. This plan fixes the known
stale text, adds a check for backticked repo paths, and writes the layout
rules into `AGENTS.md`. No Nix module changes.

## Why this matters

An agent or a reader follows a doc to `modules/home/zsh.nix`, finds nothing,
and has to search. The repo moves files often, and four plans in this series
move more. A check that fails when a doc names a missing path turns each
future move into a visible, one-line fix.

## Order

Land this plan after the plans that move files: 024, 025, 029, and 030. The
new check then starts green and stays green. If one of those plans is not
DONE in `plans/README.md`, you may still run this plan. Its executor later
fixes the doc path that the new check names.

## Current state

### The moved file

`modules/home/zsh.nix` does not exist. `modules/home/shell/` holds
`direnv.nix`, `fzf.nix`, `zoxide.nix`, and `zsh.nix`. Measured on 2026-11-27
with `rg -n 'modules/home/zsh\.nix' --glob '!plans/**' --glob '!references/**' .`:

| File (line hint) | Text around the stale path | Correct path | Why |
|---|---|---|---|
| `GLOSSARY.md` (31) | `` behind `martin.shell.viMode` in `modules/home/zsh.nix` `` | `modules/home/shell/zsh.nix` | the option is declared at `modules/home/shell/zsh.nix:21` |
| `GLOSSARY.md` (36) | `` behind `martin.shell.search` in `modules/home/zsh.nix` `` | `modules/home/shell/zsh.nix` | declared at `modules/home/shell/zsh.nix:27` |
| `docs/adr/0008-reproducible-dev-envs-and-cross-platform-purity.md` (21) | `` nix-direnv (enabled in `modules/home/zsh.nix`) `` | `modules/home/shell/direnv.nix` | `nix-direnv.enable = true;` is at `modules/home/shell/direnv.nix:7` |
| `docs/adr/0016-mbx-is-mise-managed-not-nix-managed.md` (7) | `` `home.sessionPath` (`modules/home/zsh.nix`) `` | `modules/home/session.nix` | `home.sessionPath` is set at `modules/home/session.nix:36` |
| `tests/README.md` (13) | `# evaluates modules/home/zsh.nix standalone for cheap toggles` | `modules/home/shell/zsh.nix` | see Step 2 for the check |
| `modules/home/skills/personal/nix-config-zsh-key-plane/SKILL.md` (8) | `` Reference implementation: `modules/home/zsh.nix` (^G plane) `` | `modules/home/shell/zsh.nix` | the `^G` plane lives there |
| `modules/home/skills/personal/remctl-macos-reminders/SKILL.md` (21) | `` and `~/nix-config/modules/home/zsh.nix` `` | `~/nix-config/modules/home/shell/zsh.nix` | `fpath=($HOME/.zsh/completions $fpath)` is at `modules/home/shell/zsh.nix:85` |

A docs rewrite was changing these files while this plan was written. Later
the same day the search printed only the last three rows. Fix every row the
search still prints, and skip a row that is already fixed.

The two ADRs are edited because this repo's ADRs describe the current state.
Only the path changes. The decision text stays.

### Two rows of the checks table that do not match the checks

`tests/README.md` has a table with one row per check. Two rows are wrong.

Row `smoke-build-toolchain` says:

```markdown
| `smoke-build-toolchain`             | Required Prek, Oxlint/Oxfmt, Tsgolint, Tsgo, Uv, and Ruff commands exist, plus the shipped canary Bun (and its `bunx` symlink) on Darwin. |
```

The check body in `tests/default.nix` runs four commands, then Bun on Darwin:

```nix
  smoke-build-toolchain = pkgs.runCommand "smoke-build-toolchain" { } (
    ''
      echo "Checking required Nix-only dotfiles toolchain commands..."
      ${lib.getExe pkgs.zig} version
      ${lib.getExe pkgs.typescript} --version
      ${lib.getExe pkgs.martin.uv-bin} --version
      ${lib.getExe pkgs.ruff} --version
    ''
    + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      ${lib.getExe pkgs.martin.bun-canary-bin} --version
      test -L ${pkgs.martin.bun-canary-bin}/bin/bunx
    ''
```

The excerpt leaves out a two-line comment above the Darwin part. The check
never runs Prek, Oxlint, Oxfmt, Tsgolint, or Tsgo.

Row `unit-skill-router` says the check runs
`` the `tools/skill-router` bun suite (`test/subprocess-gating.test.ts`) ``.
`tests/unit/skill-router-test.nix:33` runs plain `bun test`, which runs every
test file under `tools/skill-router/test/`. On 2026-11-27 that directory held
`frontmatter.test.ts` and `subprocess-gating.test.ts`.

### What already checks docs, and the gap

`unit-doc-links` (`tests/unit/doc-links-test.sh`) checks Markdown links. It
skips inline code, so a backticked path like `` `modules/home/zsh.nix` `` is
never checked. That gap is why the stale paths above survived.

A measurement of the gap on 2026-11-27: among `AGENTS.md`, `GLOSSARY.md`,
`tests/README.md`, and `docs/**/*.md` outside `docs/adr/` and
`docs/superpowers/`, the only backticked repo paths that did not exist were
the two in `GLOSSARY.md`. Under `docs/adr/` there were 15 more, and nearly
all are correct: an ADR that records removing `pkgs/dropbox.nix` must name
it. So the new check skips `docs/adr/` and `docs/superpowers/`.

### How a shell check is registered

`tests/default.nix`, the entry to copy:

```nix
  unit-doc-links = shellTest "unit-doc-links" {
    script = ./unit/doc-links-test.sh;
    inputs = [ pkgs.findutils pkgs.gawk ];
    args = [ self ];
  };
```

`self` is the flake source, so the script sees every tracked file. Every
registered check needs a row in the `tests/README.md` table, or the
`unit-tests-readme` check fails.

### Where the layout rules go

`ARCHITECTURE.md` held the repository layout. On 2026-11-27 the working tree
had that file deleted and a new section `## Targets and package ownership`
added to `AGENTS.md`, both uncommitted. This plan writes layout rules into
`AGENTS.md` and never recreates `ARCHITECTURE.md`.

Repo rules that apply:

- A `doc-lock` hook blocks Markdown changes outside docs work. This whole plan
  is docs work. If the hook blocks an edit, stop and report. The operator
  then opens docs work for the session.
- Writing rules for docs: short sentences, active voice, no em dashes, no
  semicolons.
- New code carries no comments. The new script below has none.
- Nix sees only files Git tracks. After creating a file, run `git add -N <path>`.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python` as commands
  you type. Run every command from the repo root. The script below may use
  `cd` and `find` internally.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| Stale path search | `rg -n 'modules/home/zsh\.nix' --glob '!plans/**' --glob '!references/**' .` | see steps |
| New test, direct | `bash tests/unit/doc-paths-test.sh .` | see steps |
| New check | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-doc-paths'` | exit 0 |
| Docs checks | `nix build --no-link '.#checks.aarch64-darwin.unit-doc-links' '.#checks.aarch64-darwin.unit-tests-readme' '.#checks.aarch64-darwin.unit-skill-hygiene'` | exit 0 |
| Shell lint | `nix develop --command shellcheck tests/unit/doc-paths-test.sh` | exit 0 |
| Format | `nix fmt -- --check tests/default.nix` | exit 0 |

## Scope

**In scope** (the only files you may modify):

- `GLOSSARY.md`, `AGENTS.md`, `tests/README.md`
- `docs/adr/0008-reproducible-dev-envs-and-cross-platform-purity.md` (one path)
- `docs/adr/0016-mbx-is-mise-managed-not-nix-managed.md` (one path)
- `modules/home/skills/personal/nix-config-zsh-key-plane/SKILL.md` (one path)
- `modules/home/skills/personal/remctl-macos-reminders/SKILL.md` (one path)
- `tests/unit/doc-paths-test.sh` (create)
- `tests/default.nix` (one new entry)
- Any other Markdown file the new check names in Step 4, for the one path it names

**Out of scope** (do NOT touch):

- `ARCHITECTURE.md` and `HOTKEYS.md`. If either exists, leave it. See STOP conditions.
- The layout tree at the top of `tests/README.md`, beyond the one comment on
  the `zsh-module-eval.nix` line. Issue #434 tracks the tree.
- The decision text of any ADR.
- `tests/unit/doc-links-test.sh` and `tests/unit/doc-checks-fixtures-test.sh`.
- Any `.nix` file other than `tests/default.nix`.

## Git workflow

- Branch: `advisor/031-maintained-docs-name-real-paths`.
- Three commits:
  1. `test: add unit-doc-paths for backticked repo paths in docs`
  2. `docs: name the real paths and the real check commands`
  3. `docs(agents): state the repository layout rules`
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Write the check and watch it fail

Create `tests/unit/doc-paths-test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

cd "$1"

docs=$(
  find docs -type f -name '*.md' -not -path 'docs/adr/*' -not -path 'docs/superpowers/*' | sort
  printf '%s\n' AGENTS.md GLOSSARY.md tests/README.md
)

tick=$(printf '\140')
repo_path="${tick}(modules|pkgs|tests|scripts|tools|lib|hosts|templates|config)/[A-Za-z0-9_./-]+${tick}"

fail=0
count=0
while IFS= read -r doc; do
  [ -f "$doc" ] || continue
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    count=$((count + 1))
    if [ ! -e "${path%/}" ]; then
      echo "$doc: $path does not exist" >&2
      fail=1
    fi
  done < <(grep -oE "$repo_path" "$doc" | tr -d "$tick" | sort -u || true)
done <<<"$docs"

if [ "$count" -eq 0 ]; then
  echo "no backticked repo path found in the maintained docs" >&2
  exit 1
fi
[ "$fail" -eq 0 ] || exit 1
echo "PASS $count backticked repo paths exist"
```

`\140` is the backtick character. Writing it that way keeps `shellcheck`
quiet about backticks inside quotes. The pattern matches a backticked token
that starts with a top-level repo directory and holds only path characters. A token with `<name>`, `*`, a
space, or `$` does not match, so placeholders and globs are skipped.

Run `git add -N tests/unit/doc-paths-test.sh`.

**Verify**: watch the check fail on a fixture. Run these three commands:

```bash
fixture=$(mktemp -d) && mkdir -p "$fixture/docs" "$fixture/modules" "$fixture/tests" && touch "$fixture/modules/real.nix" "$fixture/GLOSSARY.md" "$fixture/tests/README.md"
```

```bash
printf 'See `modules/real.nix` and `modules/missing.nix`.\n' >"$fixture/AGENTS.md" && bash tests/unit/doc-paths-test.sh "$fixture"
```

The second command exits 1 and prints
`AGENTS.md: modules/missing.nix does not exist`. If it exits 0, that is a
STOP condition.

```bash
printf 'See `modules/real.nix` and `pkgs/<name>.nix`.\n' >"$fixture/AGENTS.md" && bash tests/unit/doc-paths-test.sh "$fixture"
```

The third command exits 0 and prints `PASS 1 backticked repo paths exist`.
The Shell lint command exits 0.

Then run the "New test, direct" command on the repo and write down every
line it prints. It may print nothing and exit 0. Each line comes from a file
move. Step 4 handles them.

### Step 2: Fix the stale paths

1. Before editing `tests/README.md`, confirm which file the helper reads:
   `rg -n 'zsh\.nix' tests/lib/zsh-module-eval.nix`. Expect a path that ends
   in `modules/home/shell/zsh.nix`. If it names a different file, use that
   file's repo path in the README comment instead.
2. Run the Stale path search. For each line it prints, make the replacement
   from the table under "Current state". In each file, replace only the
   path. Keep the rest of the sentence.

**Verify**: the Stale path search prints nothing.

### Step 3: Fix the two table rows

In `tests/README.md`:

1. Read the live body of `smoke-build-toolchain` in `tests/default.nix`. If
   it runs the same commands as the excerpt above, replace the row's description with:

   ```markdown
   Zig, the TypeScript compiler, uv, and Ruff each print a version, plus the shipped canary Bun (and its `bunx` symlink) on Darwin.
   ```

   If the body differs, write one sentence that lists the commands it runs.
2. In the `unit-skill-router` row, replace
   `` (`test/subprocess-gating.test.ts`) `` with
   `` (every `*.test.ts` file under `test/`) ``. Keep the rest of the row.

Keep the table's column alignment as the neighbouring rows have it.

**Verify**: `rg -n 'Prek, Oxlint' tests/README.md` prints nothing.
`rg -n 'bun suite \(`test/subprocess-gating' tests/README.md` prints nothing.

### Step 4: Fix what else the check names

Run the "New test, direct" command again.

- If it exits 0, go to Step 5.
- For each line it prints, find the file's new home:
  `fd -t f '^<base name>$'`, with the base name of the missing path. For a
  directory, use `fd -t d`.
  - Exactly one result: replace the old path with it in the named doc.
  - No result: the path was deleted. Read the sentence. If it describes a
    thing that no longer exists, that is a STOP condition. Report the line.
  - More than one result: STOP and report the line.

Known moves from this series, to confirm what `fd` finds:

| Plan | Old location | New location |
|---|---|---|
| 024 | tool scripts and their tests under `modules/home/jj-pr/`, `modules/home/recall/`, `modules/home/doc-lock/`, and the agent-checkout script | `tools/<name>/` |
| 025 | `modules/home/ai-model-routing.nix` | `modules/home/ai-model-routing/default.nix` |
| 025 | `modules/home/agent-instructions.nix` | `modules/home/agent-instructions/default.nix` |
| 026 | the npm shims in `modules/home/cursor.nix`, and the MCP scaffold in `modules/home/lsp.nix` | `modules/home/node-shims.nix` and `modules/home/claude/mcp.nix` |
| 027 | `modules/home/claude/evals/` | `tools/claude-evals/` |
| 029 | `tests/unit/mksystem-test.nix`, `tests/unit/cleanup-legacy-dotfiles-test.sh`, `tests/unit/workspace-backend-lifecycle-test.sh` | `tests/integration/` |
| 030 | `scripts/update-hk.sh`, `update-uv.sh`, `update-hunk.sh`, `update-bun-canary.sh`, `update-zed-nightly.sh` | the same name with `-bin` before `.sh` |

**Verify**: the "New test, direct" command exits 0 and prints a `PASS` line.

### Step 5: Register the check

1. In `tests/default.nix`, add directly after the `unit-doc-links` entry:

   ```nix
     unit-doc-paths = shellTest "unit-doc-paths" {
       script = ./unit/doc-paths-test.sh;
       inputs = [ pkgs.findutils pkgs.gnugrep pkgs.coreutils ];
       args = [ self ];
     };
   ```

2. In `tests/README.md`, add a row after the `unit-doc-links` row:

   ```markdown
   | `unit-doc-paths`                    | Every backticked repo path in `AGENTS.md`, `GLOSSARY.md`, `tests/README.md`, and `docs/**/*.md` exists. Skips `docs/adr/` and `docs/superpowers/`, which may name removed files, and skips placeholders and globs. |
   ```

**Verify**: the New check, Docs checks, and Format commands exit 0. Commit
the script, the registry entry, and the README row as commit 1. Commit the
Step 2 to Step 4 edits as commit 2.

### Step 6: State the layout rules in `AGENTS.md`

Open `plans/README.md` and read the status of plans 024, 025, and 030. Add a
section to `AGENTS.md` directly after `## Targets and package ownership`. If
that section does not exist, add it directly after the first paragraph.
Include a bullet only when its plan is DONE:

```markdown
## Layout rules

- **Tools** (plan 024): A tool this repo writes keeps its source and its test in `tools/<name>/` and its package in `pkgs/<name>.nix`. `modules/` holds only the Nix wiring and installed guides.
- **Home features** (plan 025): A Home Manager feature with one file is `modules/home/<topic>.nix`. A feature with more than one file is `modules/home/<feature>/default.nix` plus its other files.
- **Packages** (plan 030): `pkgs/<name>.nix` registers as `pkgs.martin.<name>` in `pkgs/default.nix`, and its updater is `scripts/update-<name>.sh`.
- **Checks**: A check named `unit-` evaluates no real host, and one named `integration-` does. `tests/README.md` defines the prefixes.
```

Do not write the "(plan NNN)" markers into `AGENTS.md`. They only tell you
which bullet belongs to which plan. Include the **Checks** bullet only when
plan 029 is DONE. If none of the four plans is DONE, skip this step and say
so in your report.

**Verify**: `rg -n '^## Layout rules' AGENTS.md` prints one line, or you
skipped the step for the stated reason. The New check and Docs checks
commands exit 0. Commit (commit 3).

## Test plan

- New test: `tests/unit/doc-paths-test.sh`, registered as `unit-doc-paths`.
  It covers one rule: a backticked repo path in a maintained doc exists.
- Step 1 watches it fail on a fixture that names a missing path, and pass
  on a fixture that names a real path and a placeholder.
- Pattern followed: `tests/unit/doc-links-test.sh` and its registry entry.
- The skill files change text only. `unit-skill-hygiene` confirms the skill
  lists still resolve.

## Done criteria

- [ ] `rg -n 'modules/home/zsh\.nix' --glob '!plans/**' --glob '!references/**' .` returns no matches
- [ ] `bash tests/unit/doc-paths-test.sh .` exits 0
- [ ] `nix build --no-link '.#checks.aarch64-darwin.unit-doc-paths' '.#checks.aarch64-darwin.unit-doc-links' '.#checks.aarch64-darwin.unit-tests-readme'` exits 0
- [ ] `rg -n 'Prek, Oxlint' tests/README.md` returns no matches
- [ ] `test ! -e ARCHITECTURE.md` exits 0, or the file was left exactly as found
- [ ] `git status --short` lists only in-scope paths (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `ARCHITECTURE.md` exists in your checkout (`test -e ARCHITECTURE.md` exits
  0). The maintainer then has to decide whether the layout lives there or in
  `AGENTS.md`. Finish Steps 1 to 5, skip Step 6, and report.
- Step 1's fixture run with the missing path exits 0.
- Step 4 finds a path with zero or several candidates.
- The check reports more than 15 missing paths in Step 1. A larger move than
  this plan expects has happened.
- The `doc-lock` hook blocks an edit.

## Maintenance notes

- After this plan, moving or renaming a file that a maintained doc names
  fails `unit-doc-paths`. The fix is to update the doc in the same change.
- The check does not read `docs/adr/`. ADRs still describe the current
  state, so a reviewer checks ADR paths by hand when a file moves.
- The check does not read `modules/home/skills/**/SKILL.md` or the agent
  guides under `modules/home/agent-instructions/`. Those name paths on the
  installed machine as well as repo paths, so the same pattern would give
  false failures. A separate check with its own pattern could cover them.
- Unbackticked paths, such as the comments in the `tests/README.md` layout
  tree, are not checked.
