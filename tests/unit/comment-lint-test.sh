#!/usr/bin/env bash
set -uo pipefail

LINT=$(realpath "${1:-$(dirname "$0")/../../scripts/comment-lint.sh}")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0 n=0

report() {
  local name=$1 want=$2 got=$3 detail=$4
  n=$((n + 1))
  [ "$want" = "$got" ] && return 0
  fail=$((fail + 1))
  printf 'FAIL %s: want=%s got=%s\n%s\n' "$name" "$want" "$got" "$detail"
}

check_case() {
  local want_rc=$1 want_pattern=$2 name=$3 src=$4 file="$tmp/case.nix" out rc got=ok
  printf '%s' "$src" >"$file"
  out=$("$LINT" "$file" 2>&1)
  rc=$?
  if [ "$rc" -ne "$want_rc" ]; then
    got="rc($rc)"
  elif ! grep -qE "$want_pattern" <<<"$out"; then
    got="missing($want_pattern)"
  fi
  report "$name" ok "$got" "$out"
}

check_case 0 '^Hard fail:\s*$' "clean why comment passes" $'{\n  # BetterMouse owns the event tap on this host.\n  enable = false;\n}\n'
check_case 1 'over 3 lines \(4\)' "hard fail on 4-line block" $'{\n  # line 1\n  # line 2\n  # line 3\n  # line 4\n  enable = true;\n}\n'
check_case 1 'date stamp' "hard fail on date stamp" $'{\n  # Pinned on 2026-09-14 for stability.\n  enable = true;\n}\n'
check_case 1 'orphan comment' "hard fail on orphan before blank line" $'{\n  # Surge note with no code below.\n\n  enable = true;\n}\n'
check_case 1 'orphan comment' "hard fail on orphan before closing brace" $'{\n  enable = true;\n  # Trailing orphan.\n}\n'
check_case 0 'history words' "candidate on history words" $'{\n  # The old hotkey daemon was retired after the conflict.\n  enable = false;\n}\n'
check_case 0 'shares words with next line \(model, subagent\)' "candidate on repeated identifier words" $'{\n  # Default model for subagents\n  CLAUDE_CODE_SUBAGENT_MODEL = "haiku";\n}\n'

cand_only=$("$LINT" --candidates "$tmp/case.nix")
report "--candidates flag emits candidate lines only" 1 "$(grep -c 'shares words with next line (model, subagent)' <<<"$cand_only")" "$cand_only"

echo "comment-lint-test: $((n - fail))/$n passed"
[ "$fail" -eq 0 ]
