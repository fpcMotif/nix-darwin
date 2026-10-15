#!/bin/bash
# The nix check runs the hook from the store, so it passes that path in.
HOOK=${1:-$(dirname "$0")/search-guard.sh}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
PROJECT="$tmp/proj"
UMBRELLA="$tmp/devv"
mkdir -p "$PROJECT" "$UMBRELLA/repo"
seq 400 >"$PROJECT/long.ts"
seq 10 >"$PROJECT/short.ts"
export SEARCH_GUARD_UMBRELLA="$UMBRELLA"
unset SEARCH_GUARD_OFF READ_GUARD_MAX_LINES
fail=0; n=0
check() {
  want=$1; cwd=$2; cmd=$3; n=$((n + 1))
  out=$(jq -cn --arg c "$cmd" --arg d "$cwd" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' | bash "$HOOK" 2>&1 >/dev/null); rc=$?
  got=allow; [ "$rc" -eq 2 ] && got=deny
  if [ "$got" != "$want" ]; then fail=$((fail + 1)); printf 'FAIL want=%s got=%s rc=%s: [%s] %s\n  %s\n' "$want" "$got" "$rc" "$cwd" "$cmd" "$out"; fi
}

check deny  "$PROJECT" "codedb word Config"
check deny  "$PROJECT" "codedb /repo word Config"
check allow "$PROJECT" "codedb word Config | head -40"
check allow "$PROJECT" "codedb /repo explain Config"

check deny  "$UMBRELLA" "rg -n foo"
check deny  "$UMBRELLA" "grep -rn foo ."
check deny  "$UMBRELLA" "cd . && rg -n foo"
check allow "$UMBRELLA" "rg -n foo repo/"
check allow "$UMBRELLA" "cd repo && rg -n foo"
check allow "$PROJECT" "rg -n foo"

check deny  "$PROJECT" "bat -pp long.ts"
check deny  "$PROJECT" "cat long.ts"
check deny  "$PROJECT" "bat -pp $PROJECT/long.ts"
check deny  "$PROJECT" "wc -l long.ts && bat -pp long.ts"
check deny  "$PROJECT" "bat -pp short.ts long.ts"
check deny  "$PROJECT" "cat long.ts | less"
check allow "$PROJECT" "bat -pp short.ts"
check allow "$PROJECT" "bat -pp --line-range 1:40 long.ts"
check allow "$PROJECT" "bat -pp -r 1:40 long.ts"
check allow "$PROJECT" "bat -pp -r1:40 long.ts"
check allow "$PROJECT" "cat long.ts | head -40"
check allow "$PROJECT" "cat long.ts | wc -l"
check allow "$PROJECT" "bat -pp long.ts | rg -n 12"
check allow "$PROJECT" "bat -pp missing.ts"

check allow "$PROJECT" "grep -n cancelled short.ts"
check allow "$PROJECT" "rg -n 'a|b|c|d' src/"
check allow "$PROJECT" "rg -n -m 40 'a|b|c|d' \$T | head -40"
check allow "$PROJECT" $'jj describe -m \'fix: x\ngrep -q exits\''

SEARCH_GUARD_OFF=1 check allow "$PROJECT" "codedb word Config"
READ_GUARD_MAX_LINES=500 check allow "$PROJECT" "bat -pp long.ts"

printf '%s/%s rows passed\n' "$((n - fail))" "$n"
[ "$fail" -eq 0 ]
