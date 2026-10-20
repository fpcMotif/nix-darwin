#!/usr/bin/env bash
# Tier 2 (opt-in, real-machine) verification for the shared review/cleanup
# defaults and their posting guards (issue #367, narrowed scope). Run AFTER
# `just switch` and after wiring modules/home/agent-routing per its README.
#
# What this checks, per host:
#   * Guide load (file level): the rendered development guide carries the
#     "Review and cleanup" block exactly once. This proves activation applied
#     the wiring; it does not ask a model anything.
#   * Posting guard: Codex through `codex execpolicy check` (behavioral: the
#     policy engine decides, no command runs). OMP through the presence of the
#     bash.patterns rules in config.yml (schema-confirmed mechanism; live
#     prompt behavior still needs one manual TUI check). Amp is guidance-only
#     BY DESIGN and reported as such, never as a pass.
#
# Honesty rule (design review, 2026-09-17): these are command guards on
# `gh pr comment` / `gh pr review`, not a boundary on every GitHub write.
# `gh api` writes are unguarded everywhere; the script prints that gap.
#
# Exit status: 0 iff there are zero FAILs. SKIPs (host absent) do not fail.
set -uo pipefail

pass=0
fail=0
skip=0

green() { printf '\033[32m%s\033[0m' "$1"; }
red() { printf '\033[31m%s\033[0m' "$1"; }
yellow() { printf '\033[33m%s\033[0m' "$1"; }
blue() { printf '\033[34m%s\033[0m' "$1"; }

ok() {
  printf '  %s %s\n' "$(green PASS)" "$1"
  pass=$((pass + 1))
}
bad() {
  printf '  %s %s\n' "$(red FAIL)" "$1"
  fail=$((fail + 1))
}
na() {
  printf '  %s %s\n' "$(yellow SKIP)" "$1"
  skip=$((skip + 1))
}
info() { printf '  %s %s\n' "$(blue INFO)" "$1"; }

section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

need() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'verify-review-guards: missing required tool: %s\n' "$1" >&2
    exit 2
  }
}
need jq

# --- Guide load (file level) -------------------------------------------------

section "Guide load (rendered development guides)"

check_guide() {
  label=$1
  path=$2
  if [ ! -f "$path" ]; then
    bad "$label: $path absent (run \`just switch\` after wiring)"
    return
  fi
  n=$(grep -c '^## Review and cleanup$' "$path" || true)
  if [ "$n" -eq 1 ]; then
    ok "$label: routing block present exactly once"
  elif [ "$n" -eq 0 ]; then
    bad "$label: routing block missing from $path"
  else
    bad "$label: routing block appears $n times in $path (double inclusion)"
  fi
}

check_guide "shared" "$HOME/.config/agent-guidance/development.md"
check_guide "codex" "$HOME/.codex/guidance/development.md"
check_guide "omp" "$HOME/.omp/agent/guidance/development.md"
check_guide "claude" "$HOME/.claude/guidance/development.md"

# --- Codex: tested command guard ----------------------------------------------

section "Codex posting guard (execpolicy)"

if ! command -v codex >/dev/null 2>&1; then
  na "codex not installed"
else
  RULES="$HOME/.codex/rules/default.rules"
  if [ ! -f "$RULES" ]; then
    bad "codex: $RULES missing — the guide's 'fail closed' claim is false until it exists"
  else
    decision() {
      codex execpolicy check --rules "$RULES" -- "$@" 2>/dev/null | jq -r '.decision // "none"'
    }
    d=$(decision gh pr comment 1 --body x)
    if [ "$d" = "prompt" ] || [ "$d" = "forbidden" ]; then
      ok "codex: 'gh pr comment' -> $d (fails closed under approval_policy=never)"
    else
      bad "codex: 'gh pr comment' decision is '$d', expected prompt or forbidden"
    fi
    d=$(decision gh pr review 1 --approve)
    if [ "$d" = "prompt" ] || [ "$d" = "forbidden" ]; then
      ok "codex: 'gh pr review' -> $d (fails closed under approval_policy=never)"
    else
      bad "codex: 'gh pr review' decision is '$d', expected prompt or forbidden"
    fi
    d=$(decision git status)
    if [ "$d" = "none" ]; then
      ok "codex: 'git status' unmatched (guard is scoped to the two posting commands)"
    else
      bad "codex: 'git status' unexpectedly matched with decision '$d'"
    fi
    d=$(decision gh api repos/o/r/issues -f title=x)
    if [ "$d" = "none" ]; then
      info "codex: 'gh api' writes are unguarded — known gap, the guide rule is the only control"
    else
      info "codex: 'gh api' matched decision '$d' — guard grew; update the honesty notes"
    fi
  fi
fi

# --- OMP: command guard (schema-confirmed mechanism) ---------------------------

section "OMP posting guard (bash.patterns)"

if ! command -v omp >/dev/null 2>&1; then
  na "omp not installed"
elif [ ! -f "$HOME/.omp/agent/config.yml" ]; then
  na "omp: ~/.omp/agent/config.yml absent"
else
  # Query the live setting, not the file: config.yml key order and layout are
  # omp's business, and a grepped string would pass even if the rules never
  # parsed into the setting.
  patterns=$(omp config get bash.patterns --json 2>/dev/null | jq -c '.value // []') || patterns="[]"
  if [ "$(printf '%s' "$patterns" | jq -r '[.[] | select(.approval == "prompt") | .match] | sort | join(" ")')" = "gh pr comment* gh pr review*" ]; then
    ok "omp: bash.patterns prompts on exactly 'gh pr comment*' and 'gh pr review*'"
  else
    bad "omp: bash.patterns does not hold the two posting rules with approval=prompt (got: $patterns)"
  fi
  info "omp: bash.patterns gates the bash tool only; a shell spawned through eval is not covered"
  info "omp: docs say user policy 'may still prompt or block' under yolo; confirm once by hand in the TUI"
fi

# --- Amp: guidance only, by design ----------------------------------------------

section "Amp posting guard"

if ! command -v amp >/dev/null 2>&1; then
  na "amp not installed"
else
  if [ -f "$HOME/.config/amp/AGENTS.md" ]; then
    ok "amp: ~/.config/amp/AGENTS.md installed (points at the shared rules)"
  else
    bad "amp: ~/.config/amp/AGENTS.md missing — Amp has no route to the shared defaults"
  fi
  info "amp: guidance only. amp.permissions has no command-scoped matching, and a Bash-wide ask rule was rejected as too broad"
fi

# --- agy ------------------------------------------------------------------------

section "agy"

if command -v agy >/dev/null 2>&1; then
  info "agy: installed — covered by the shared ~/AGENTS.md Develop pointer only"
else
  na "agy not installed"
fi

section "Summary"
printf '  %s %d  %s %d  %s %d\n' "$(green PASS)" "$pass" "$(red FAIL)" "$fail" "$(yellow SKIP)" "$skip"
info "everywhere: 'gh api' writes are unguarded; the routing block's Posting rule is the only control"
[ "$fail" -eq 0 ]
