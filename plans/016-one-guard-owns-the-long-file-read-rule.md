# Plan 016: One guard owns the long-file read rule, and its line limit is configurable

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 534fc39..HEAD -- modules/home/claude/hooks modules/home/antigravity`
> If `shell-guard.sh` or `search-guard.sh` changed, compare the "Current
> state" excerpts against the live code. On a mismatch, treat it as a STOP
> condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: MED
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `534fc39`, 2026-11-17

## At a glance

Two hook scripts each deny `cat` or `bat` of a long file, with different
parsers and different limits. `search-guard.sh` reads the limit from
`READ_GUARD_MAX_LINES`, and `shell-guard.sh` hard-codes 300, so raising the
variable has no effect. This plan keeps the rule only in `shell-guard.sh` and
makes it read the variable. Every other rule in both scripts is unchanged.

## Why this matters

Both hooks run on every Bash call in Claude Code and Antigravity. A long read
is judged twice by two parsers that disagree on edge cases. The setting
`READ_GUARD_MAX_LINES`, seeded at `modules/home/claude.nix:373`, is a knob
that cannot loosen the rule, because the second guard ignores it.

## Behaviour change to accept

After this plan:

1. `cat long.ts | less` is allowed. `shell-guard.sh` allows every pipe.
   `search-guard.sh` denied pipes into commands outside its short list.
2. `SEARCH_GUARD_OFF=1` no longer switches off the long-read rule.
   `TOOL_GUARD_OFF=1` does, as it already does today for the `shell-guard.sh` copy.
3. `READ_GUARD_MAX_LINES=500` lets a 400-line file through. Today it is denied.

If the operator does not accept item 1, stop before Step 1 and report.

## Current state

Files:

- `modules/home/claude/hooks/shell-guard.sh` — segment-based Bash guard.
- `modules/home/claude/hooks/search-guard.sh` — search and read guard.
- `modules/home/claude/hooks/shell-guard-test.sh` — check `unit-shell-guard`.
- `modules/home/claude/hooks/search-guard-test.sh` — check `unit-search-guard`.
- `modules/home/antigravity/default.nix` — runs both guards through `agy-guard.sh`. Not edited.

`shell-guard.sh:109-132` today:

```bash
read_too_long() {
  local seg=$1 rest arg f n args
  rest=${CMD_WITHOUT_HEREDOCS#*"$seg"}; rest=${rest#"${rest%%[![:space:]]*}"}
  case $rest in '||'*) ;; '|'*) return 1 ;; esac
  case $seg in *'>'*|*'<'*) return 1 ;; esac
  read -r -a args <<<"$seg"
  for arg in "${args[@]:1}"; do
    case $arg in
      -r*|--line-range*) return 1 ;;
      -*) continue ;;
    esac
    f=${arg#[\"\']}; f=${f%[\"\']}
    case $f in
      '~/'*) f=$HOME/${f#\~/} ;;
      *'$'*|*'*'*|*'?'*|*'`'*) continue ;;
      /*) ;;
      *) f=$WORK_DIR/$f ;;
    esac
    [ -f "$f" ] || continue
    n=$(wc -l <"$f"); n=${n//[[:space:]]/}
    [ "$n" -gt 300 ] && { long_file=$arg; long_lines=$n; return 0; }
  done
  return 1
}
```

`shell-guard.sh:150-152` today. The deny message ends with a fixed number:

```bash
    cat|bat)
      [ -z "${TOOL_GUARD_OFF:-}" ] && read_too_long "$seg" \
        && deny "shell-guard: $long_file has $long_lines lines, ... A pipe ('cat FILE | head') or a file of 300 lines or fewer is allowed." ;;
```

`search-guard.sh:14-18` today, used only by the long-read rule:

```bash
unranged_read_targets() {
  printf '%s' "$CMD" | grep -Eo '(^|[[:space:]])(cat|bat)[[:space:]]+[^|;&]*(\|[[:space:]]*[A-Za-z]+)?' \
    | grep -Ev '\|[[:space:]]*(head|tail|rg|grep|wc|jq|cut|awk|sort|uniq)$' \
    | sed -E 's/\|.*$//; s/^[[:space:]]*(cat|bat)[[:space:]]+//' | tr ' ' '\n' | grep -v '^-'
}
```

`search-guard.sh:36-44` today, the rule to delete:

```bash
if command_has '(^|[;&|[:space:]])(cat|bat)[[:space:]]' \
   && ! command_has '--line-range|(^|[[:space:]])-r([[:space:]]|[0-9:])'; then
  for f in $(unranged_read_targets); do
    path="$f"; [ "${path#/}" = "$path" ] && path="$CWD/$f"
    [ -f "$path" ] || continue
    lines=$(wc -l < "$path" 2>/dev/null | tr -d " " || echo 0)
    [ "$lines" -gt "${READ_GUARD_MAX_LINES:-300}" ] && deny "search-guard: $f has $lines lines. ..."
  done
fi
exit 0
```

`search-guard-test.sh` today: line 9 creates `long.ts`, line 12 is
`unset SEARCH_GUARD_OFF READ_GUARD_MAX_LINES`, lines 33-46 are fourteen
long-read rows, and line 54 is
`READ_GUARD_MAX_LINES=500 check allow "$PROJECT" "bat -pp long.ts"`.
Its `check` takes `want cwd cmd`.

`shell-guard-test.sh:60-72` today. Its `check` takes `want cmd [cwd]`, and the
default `cwd` is `$PLAIN`:

```bash
seq 400 >"$PLAIN/big.txt"; seq 300 >"$PLAIN/edge.txt"
check deny  "cat big.txt"
check deny  "bat -pp big.txt"
check deny  "cat $PLAIN/big.txt"
check deny  "z $PLAIN && cat big.txt" "$JJ"
check deny  "cat edge.txt big.txt"
check deny  "cat big.txt || true"
check allow "cat edge.txt"
check allow "bat -pp -r 1:40 big.txt"
check allow "bat -pp --line-range=1:40 big.txt"
check allow "cat big.txt | head -n 40"
check allow "cat big.txt > copy.txt"
check allow "cat missing.txt"
```

Both test scripts print `N/N rows passed` and exit non-zero on any failure.

Repo rules that apply:

- A `doc-lock` hook blocks new or changed code comments outside docs work.
  Add no comments. A comment may leave only with the code it describes.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`. Edit files
  with your edit tool. The `sed` inside the hook scripts is code, not a
  command you run.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| Shell guard rows | `bash modules/home/claude/hooks/shell-guard-test.sh` | last line `N/N rows passed`, exit 0 |
| Search guard rows | `bash modules/home/claude/hooks/search-guard-test.sh` | last line `N/N rows passed`, exit 0 |
| Checks | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-shell-guard' '.#checks.aarch64-darwin.unit-search-guard' '.#checks.aarch64-darwin.unit-agy-guard'` | exit 0 |

The direct `bash` runs need `jq`, `zoxide`, and GNU tools on PATH. If one is
missing, use the `nix build` form only.

## Scope

**In scope** (the only files you may modify):

- `modules/home/claude/hooks/shell-guard.sh`
- `modules/home/claude/hooks/search-guard.sh`
- `modules/home/claude/hooks/shell-guard-test.sh`
- `modules/home/claude/hooks/search-guard-test.sh`

**Out of scope** (do NOT touch):

- The `codedb word` rule and the umbrella-root `rg` rule in `search-guard.sh`.
- Every other rule in `shell-guard.sh`.
- `modules/home/claude.nix`. The seed `READ_GUARD_MAX_LINES = "300"` stays.
- `modules/home/antigravity/`.
- `modules/home/claude/search-eval.md` and `shell-guard-eval.md`. They are
  dated evaluation records. Report stale lines, do not edit them.

## Git workflow

- Branch: `advisor/016-one-guard-owns-the-long-file-read-rule`.
- One commit: `fix(guards): keep the long-read rule in shell-guard and honor READ_GUARD_MAX_LINES`.
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Add the failing rows to `shell-guard-test.sh`

Directly above the line `seq 400 >"$PLAIN/big.txt"; seq 300 >"$PLAIN/edge.txt"`, add:

```bash
unset READ_GUARD_MAX_LINES
```

Directly after the row `check allow "cat missing.txt"`, add:

```bash
check deny  "wc -l big.txt && bat -pp big.txt"
check allow "bat -pp -r1:40 big.txt"
check allow "bat -pp big.txt | rg -n 12"
check allow "cat big.txt | less"
READ_GUARD_MAX_LINES=500 check allow "bat -pp big.txt"
READ_GUARD_MAX_LINES=100 check deny  "cat edge.txt"
```

**Verify**: `bash modules/home/claude/hooks/shell-guard-test.sh` exits non-zero
and prints exactly two `FAIL` lines, for the two `READ_GUARD_MAX_LINES` rows.
Any other `FAIL` line is a STOP condition.

### Step 2: Make `shell-guard.sh` read the limit

In `read_too_long`, change:

```bash
    [ "$n" -gt 300 ] && { long_file=$arg; long_lines=$n; return 0; }
```

to:

```bash
    [ "$n" -gt "${READ_GUARD_MAX_LINES:-300}" ] && { long_file=$arg; long_lines=$n; return 0; }
```

In the `cat|bat)` deny message, change the text
`a file of 300 lines or fewer is allowed` to
`a file of ${READ_GUARD_MAX_LINES:-300} lines or fewer is allowed`.
The message is in double quotes, so the variable expands.

**Verify**: `bash modules/home/claude/hooks/shell-guard-test.sh` exits 0.

### Step 3: Delete the rule from `search-guard.sh`

1. Delete the function `unranged_read_targets` (lines 14-18) and the blank line after it.
2. Delete the `if command_has '(^|[;&|[:space:]])(cat|bat)[[:space:]]' ... fi`
   block (lines 36-44) and the blank line before it. Keep the final `exit 0`.

**Verify**: `rg -n 'unranged_read_targets|READ_GUARD_MAX_LINES|cat\|bat' modules/home/claude/hooks/search-guard.sh` prints nothing.
`rg -n 'has_subpath_arg|command_has' modules/home/claude/hooks/search-guard.sh`
still shows each helper defined once and used at least once.

### Step 4: Remove the moved rows from `search-guard-test.sh`

1. Delete line 9, `seq 400 >"$PROJECT/long.ts"`. Keep line 10, which creates
   `short.ts`. A later row still reads it.
2. Change line 12 to `unset SEARCH_GUARD_OFF`.
3. Delete the fourteen rows from `check deny  "$PROJECT" "bat -pp long.ts"`
   through `check allow "$PROJECT" "bat -pp missing.ts"`, and one of the two
   blank lines around them.
4. Delete the row `READ_GUARD_MAX_LINES=500 check allow "$PROJECT" "bat -pp long.ts"`.

**Verify**: `bash modules/home/claude/hooks/search-guard-test.sh` exits 0.
`rg -n 'long\.ts|READ_GUARD' modules/home/claude/hooks/search-guard-test.sh` prints nothing.

### Step 5: Run the three checks

**Verify**: the Checks command exits 0.

## Test plan

- Six new rows in `shell-guard-test.sh`. Two of them fail before Step 2 and
  pass after it. That proves the limit is now read from the variable.
- The row `check allow "cat big.txt | less"` records the accepted behaviour change.
- `unit-agy-guard` proves the Antigravity wrapper still runs both scripts.

## Done criteria

- [ ] `rg -c 'READ_GUARD_MAX_LINES' modules/home/claude/hooks/shell-guard.sh` prints `2`
- [ ] `rg -n 'gt 300' modules/home/claude/hooks` prints nothing
- [ ] `rg -n 'wc -l' modules/home/claude/hooks/search-guard.sh` prints nothing
- [ ] The Checks command exits 0
- [ ] `git status --short` lists only the four in-scope files (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- The operator does not accept that `cat long | less` becomes allowed.
- Step 1 shows a `FAIL` line other than the two `READ_GUARD_MAX_LINES` rows.
  Then `shell-guard.sh` does not cover a case this plan assumed it covers.
- `unit-agy-guard` fails. Report the failing row. Do not edit files under
  `modules/home/antigravity/`.
- Another file under `modules/` calls `unranged_read_targets`.

## Maintenance notes

- The long-read rule now has one switch, `TOOL_GUARD_OFF`, and one limit,
  `READ_GUARD_MAX_LINES`.
- Stale text to report, not edit: `modules/home/claude/search-eval.md:47`
  still lists a `cat`/`bat` rule under `search-guard.sh`.
- A reviewer should run a real `bat -pp` on a 400-line file in Claude Code
  after the next switch and confirm one deny message, from `shell-guard`.
