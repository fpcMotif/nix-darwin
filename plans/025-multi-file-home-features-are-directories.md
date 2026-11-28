# Plan 025: A multi-file feature in `modules/home` is a directory with `default.nix`

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5442cca..HEAD -- modules/home/default.nix modules/home/shell modules/home/ai-model-routing.nix modules/home/ai-model-routing.py modules/home/agent-instructions.nix tests/unit/ai-model-routing-test.nix`
> If any of these changed, compare the "Current state" excerpts against the
> live code. Plans 021 and 028 both edit `modules/home/agent-instructions.nix`
> on purpose. Their changes are described under "Current state". Any other
> mismatch is a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: plans/024-repo-tools-keep-their-sources-in-tools.md
- **Category**: tech-debt
- **Planned at**: commit `5442cca`, 2026-11-27

## At a glance

`modules/home` uses several layouts for the same thing: a feature with more
than one file is sometimes a directory with `default.nix`, sometimes a
directory whose files are imported one by one, and sometimes a flat `.nix`
file beside a directory of the same name. This plan converts three features to
the newest layout, a directory imported through its `default.nix`. Every
installed file stays byte-for-byte the same.

## Why this matters

When the layout varies, a reader cannot predict where a feature's Nix file is,
and each new feature copies whichever neighbour its author opened. The four
most recent multi-file features (`doc-lock`, `workspace-backend`, `recall`,
`antigravity`) all chose a directory with `default.nix`. This plan makes the
older ones match, so the rule has no counter-examples to copy.

## Current state

### The import list

`modules/home/default.nix:4-41` (the whole `imports` list):

```nix
  imports = [
    ./cleanup.nix
    ./packages.nix
    ./session.nix
    ./shell/zsh.nix
    ./shell/direnv.nix
    ./shell/fzf.nix
    ./shell/zoxide.nix
    ./ai-cli.nix
    ./pi.nix
    ./ai-model-routing.nix
    ./agent-surface.nix
    ./skill-placement.nix
    ./agent-instructions.nix
    ./obsidian.nix
    ./tmux.nix
    ./git.nix
    ./hk.nix
    ./doc-lock
    ./recall
    ./jujutsu.nix
    ./workspace-backend
    ./ghostty.nix
    ./kitty.nix
    ./yazi.nix
    ./prompt.nix
    ./claude.nix
    ./antigravity
    ./lsp.nix
    ./droid.nix
    ./zed.nix
    ./crush.nix
    ./amp.nix
    ./ssh.nix
    ./cursor.nix
    ./skill-router.nix
    ./iets.nix
  ];
```

The target layout is the one `./doc-lock`, `./recall`, `./workspace-backend`,
and `./antigravity` already use. Exemplar: `modules/home/recall/` holds
`default.nix` and `guide.md`, and the list above imports it as `./recall`.

### Feature 1: `shell/` has no `default.nix`

`modules/home/shell/` holds `zsh.nix`, `direnv.nix`, `fzf.nix`, and
`zoxide.nix`. The list above imports each one by name.

`tests/lib/zsh-module-eval.nix:66-71` also imports the four files one by one,
on purpose, so a test can leave some out:

```nix
      ../../modules/home/shell/zsh.nix
    ]
    ++ lib.optional includeSession ../../modules/home/session.nix
    ++ lib.optional includeDirenv ../../modules/home/shell/direnv.nix
    ++ lib.optional includeFzf ../../modules/home/shell/fzf.nix
    ++ lib.optional includeZoxide ../../modules/home/shell/zoxide.nix
```

That file keeps working unchanged, because the four files do not move.

### Feature 2: `ai-model-routing.nix` and a loose Python file

`modules/home/ai-model-routing.nix` (whole file):

```nix
{ pkgs, lib, config, ... }:

let
  routing = import ../shared/agent-model-routing.nix { inherit lib; };
  policy = pkgs.writeText "agent-model-routing.json" (builtins.toJSON routing.policy);
  python = pkgs.python3.withPackages (pythonPackages: [ pythonPackages.pyyaml ]);
in
{
  # Pi and OMP own mutable runtime settings. This adapter reasserts only model
  # routing fields from the shared semantic policy and preserves other state.
  home.activation.aiModelRouting = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${python}/bin/python3 ${./ai-model-routing.py} \
      ${policy} ${config.home.homeDirectory}
  '';
}
```

`modules/home/ai-model-routing.py` sits beside it. It is the only Python file
at the top of `modules/home`. One test reads it,
`tests/unit/ai-model-routing-test.nix:49-50`:

```nix
  ${routingPython}/bin/python3 ${./ai-model-routing-test.py} \
    ${../../modules/home/ai-model-routing.py} ${policy}
```

If plan 028 landed first, the activation entry is wrapped in
`lib.mkIf config.martin.piOmp.enable (...)`. Keep that wrapper as you find it.

### Feature 3: `agent-instructions.nix` beside `agent-instructions/`

`modules/home/agent-instructions.nix` is the module. The directory
`modules/home/agent-instructions/` holds its data: `AGENTS.md`, `guides.nix`,
and the subdirectories `codex/`, `omp/`, and `shared/`. No `default.nix`
exists in that directory today.

The module's relative paths, `modules/home/agent-instructions.nix:5` and `:21-25`:

```nix
  modelRouting = import ../shared/agent-model-routing.nix { inherit lib; };
```

```nix
    ".config/agent-routing/README.md" = ../../config/omp/README.md;
    ".omp/agent/agents/codex-plan-deployer.md" = ./agent-instructions/omp/agent/agents/codex-plan-deployer.md;
    ".omp/agent/agents/codex-spark-worker.md" = ./agent-instructions/omp/agent/agents/codex-spark-worker.md;
    ".omp/agent/agents/designer.md" = ./agent-instructions/omp/agent/agents/designer.md;
    ".omp/agent/agents/oracle.md" = ./agent-instructions/omp/agent/agents/oracle.md;
```

If plan 021 landed first, line 21 reads
`./agent-instructions/omp/agent-routing/README.md` instead of
`../../config/omp/README.md`.

`rg -n '\./|\.\./' modules/home/agent-instructions.nix` printed only those six
lines on 2026-11-27.

Other files read `modules/home/agent-instructions/guides.nix` by path:
`modules/home/agent-surface.nix:74`, `justfile:179`,
`tests/integration/configurations-eval-test.nix:13`, and
`tests/unit/agent-guides-test.nix:5`. `guides.nix` does not move, so none of
them changes.

### What this plan leaves flat, and why

- `claude.nix` beside `claude/`. Plan 017 edits `claude.nix`, and
  `tests/unit/skill-hygiene-test.nix` reads that file as text by path. Moving
  it is a separate change for after plan 017 lands.
- `ghostty.nix` beside `ghostty-themes/`, and `skill-placement.nix` beside
  `skills/`. The directory names differ from the module names, so they do not
  collide.
- Every single-file topic (`git.nix`, `tmux.nix`, and the rest). One file
  needs no directory.

Repo rules that apply:

- A `doc-lock` hook blocks new or changed code comments outside docs work.
  This plan moves files whole and changes path literals only. Do not add,
  reword, or delete any comment. If the hook blocks an edit, stop and report.
- Nix sees only files Git tracks. `git mv` stages its result. After creating
  `modules/home/shell/default.nix`, run `git add -N modules/home/shell/default.nix`.
- Nix names a store copy of a file after the file's base name. Keep every
  moved file's base name, or the build changes.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`. Run every
  command from the repo root.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| Invariance | `nix eval --raw '.#darwinConfigurations.f.config.home-manager.users.martinfan.home.activationPackage.drvPath'` | prints one `.drv` path |
| Linux invariance | `nix eval --raw '.#nixosConfigurations.x230.config.system.build.toplevel.drvPath'` | prints one `.drv` path |
| Checks | `nix build --no-link '.#checks.aarch64-darwin.unit-ai-model-routing' '.#checks.aarch64-darwin.unit-module-seams' '.#checks.aarch64-darwin.unit-agent-guides' '.#checks.aarch64-darwin.unit-zsh-vi-mode' '.#checks.aarch64-darwin.integration-configurations-eval'` | exit 0 |
| Guides recipe | `just guides` | lists guide files, exit 0 |
| Format | `nix fmt -- --check modules/home tests/unit/ai-model-routing-test.nix` | exit 0 |

## Scope

**In scope** (the only files you may modify):

- `modules/home/default.nix` (the `imports` list)
- `modules/home/shell/default.nix` (create)
- `modules/home/ai-model-routing.nix` → `modules/home/ai-model-routing/default.nix` (move, one path literal)
- `modules/home/ai-model-routing.py` → `modules/home/ai-model-routing/ai-model-routing.py` (move)
- `tests/unit/ai-model-routing-test.nix` (line 50)
- `modules/home/agent-instructions.nix` → `modules/home/agent-instructions/default.nix` (move, path literals)

**Out of scope** (do NOT touch):

- `modules/home/claude.nix`, `modules/home/ghostty.nix`,
  `modules/home/skill-placement.nix`, and every single-file module.
- `tests/lib/zsh-module-eval.nix`. It imports the shell files one by one on purpose.
- `modules/home/agent-instructions/guides.nix` and every file under
  `agent-instructions/codex`, `omp`, and `shared`.
- The body of any moved module beyond its path literals.
- `ARCHITECTURE.md`, `docs/adr/0010-*.md`, and `tests/README.md`. They name
  `ai-model-routing.nix`. Plan 031 updates the maintained docs.

## Git workflow

- Branch: `advisor/025-multi-file-home-features-are-directories`.
- Three commits:
  1. `refactor(shell): import the shell modules through shell/default.nix`
  2. `refactor(routing): move the Pi routing adapter into its own directory`
  3. `refactor(agent-instructions): move the module into its data directory`
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Check the precondition and record the baselines

Run `test ! -e modules/home/jj-pr`. It must exit 0. If the directory exists,
plan 024 has not landed. That is a STOP condition.

Run the Invariance and Linux invariance commands. Save the outputs as
`BEFORE` and `LINUX_BEFORE`.

### Step 2: Give `shell/` a `default.nix`

1. Create `modules/home/shell/default.nix`:

   ```nix
   {
     imports = [
       ./zsh.nix
       ./direnv.nix
       ./fzf.nix
       ./zoxide.nix
     ];
   }
   ```

2. Run `git add -N modules/home/shell/default.nix`.
3. In `modules/home/default.nix`, replace the four lines `./shell/zsh.nix`,
   `./shell/direnv.nix`, `./shell/fzf.nix`, `./shell/zoxide.nix` with the one
   line `./shell`.

**Verify**: the Invariance command prints `BEFORE` exactly.
`nix build --no-link '.#checks.aarch64-darwin.unit-zsh-vi-mode' '.#checks.aarch64-darwin.unit-module-seams'` exits 0.
Commit (commit 1).

### Step 3: Move the routing adapter into a directory

1. `mkdir -p modules/home/ai-model-routing`
2. `git mv modules/home/ai-model-routing.nix modules/home/ai-model-routing/default.nix`
3. `git mv modules/home/ai-model-routing.py modules/home/ai-model-routing/ai-model-routing.py`
4. In `modules/home/ai-model-routing/default.nix`, change
   `import ../shared/agent-model-routing.nix` to
   `import ../../shared/agent-model-routing.nix`. Leave
   `${./ai-model-routing.py}` as it is.
5. In `modules/home/default.nix`, change `./ai-model-routing.nix` to
   `./ai-model-routing`.
6. In `tests/unit/ai-model-routing-test.nix` line 50, change the path to
   `${../../modules/home/ai-model-routing/ai-model-routing.py}`.

**Verify**: the Invariance command prints `BEFORE` exactly.
`nix build --no-link '.#checks.aarch64-darwin.unit-ai-model-routing'` exits 0.
Commit (commit 2).

### Step 4: Move the agent-instructions module into its directory

1. `git mv modules/home/agent-instructions.nix modules/home/agent-instructions/default.nix`
2. In `modules/home/agent-instructions/default.nix`:
   - Change `import ../shared/agent-model-routing.nix` to
     `import ../../shared/agent-model-routing.nix`.
   - In every path literal that starts with `./agent-instructions/`, remove
     that prefix so it starts with `./`. Example:
     `./agent-instructions/omp/agent/agents/oracle.md` becomes
     `./omp/agent/agents/oracle.md`.
   - If the line for `".config/agent-routing/README.md"` still reads
     `../../config/omp/README.md`, change it to `../../../config/omp/README.md`.
3. In `modules/home/default.nix`, change `./agent-instructions.nix` to
   `./agent-instructions`.

**Verify**:

- `rg -n '\./agent-instructions/' modules/home/agent-instructions/default.nix`
  prints nothing.
- The Invariance command prints `BEFORE` exactly.
- The Linux invariance command prints `LINUX_BEFORE` exactly.
- The Checks command exits 0.
- `just guides` exits 0 and lists files.
- The Format command exits 0.

Commit (commit 3).

## Test plan

- No new test. These are moves, and the gate is build invariance on the
  Darwin home and the `x230` system, checked after every step.
- The five checks in the Checks command read the moved modules or their
  neighbours by path, so they prove no reader was left behind.

## Done criteria

- [ ] `test -f modules/home/shell/default.nix && test -f modules/home/ai-model-routing/default.nix && test -f modules/home/agent-instructions/default.nix` exits 0
- [ ] `test ! -e modules/home/ai-model-routing.nix && test ! -e modules/home/ai-model-routing.py && test ! -e modules/home/agent-instructions.nix` exits 0
- [ ] `rg -n 'shell/(zsh|direnv|fzf|zoxide)\.nix|ai-model-routing\.nix|agent-instructions\.nix' modules/home/default.nix` returns no matches
- [ ] The Checks command exits 0
- [ ] The invariance checks in Steps 2, 3, and 4 passed
- [ ] `git status --short` lists only in-scope paths (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `modules/home/jj-pr` still exists.
- An invariance check fails. The most likely cause is a file whose base name
  changed, or a directory that Nix copies whole and that now holds a new
  `default.nix`. Report which step failed.
- `modules/home/agent-instructions.nix` holds a relative path that this plan
  does not list.
- A file outside the Scope list imports `ai-model-routing.nix` or
  `agent-instructions.nix` by path. Check with
  `rg -n 'ai-model-routing\.(nix|py)|agent-instructions\.nix' --glob '*.nix' --glob '*.sh' --glob 'justfile' .`
- The `doc-lock` hook blocks an edit.

## Maintenance notes

- The rule after this plan: in `modules/home`, a feature with one file is
  `<topic>.nix`. A feature with more than one file is `<feature>/default.nix`
  plus its other files, imported as `./<feature>`. Plan 031 writes this into
  `AGENTS.md`.
- `claude.nix` is the remaining counter-example. Convert it after plan 017
  lands, and update the path in `tests/unit/skill-hygiene-test.nix` in the
  same change.
- The working tree at `5442cca` had uncommitted edits to Markdown files under
  `modules/home/agent-instructions/`. They are unrelated. Leave them alone.
