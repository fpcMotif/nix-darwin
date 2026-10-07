#!/bin/bash
# Table test for search-guard.sh: one row per working directory and command, expected verdict first.
# Run: bash search-guard-test.sh [path/to/search-guard.sh]  (the nix check passes the store path)
HOOK=${1:-$(dirname "$0")/search-guard.sh}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
P="$tmp/proj"
U="$tmp/devv"
mkdir -p "$P" "$U/repo"
seq 400 >"$P/long.ts"
seq 10 >"$P/short.ts"
export SEARCH_GUARD_UMBRELLA="$U"
unset SEARCH_GUARD_OFF READ_GUARD_MAX_LINES
fail=0; n=0
check() {
  want=$1; cwd=$2; cmd=$3; n=$((n + 1))
  out=$(jq -cn --arg c "$cmd" --arg d "$cwd" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' | bash "$HOOK" 2>&1 >/dev/null); rc=$?
  got=allow; [ "$rc" -eq 2 ] && got=deny
  if [ "$got" != "$want" ]; then fail=$((fail + 1)); printf 'FAIL want=%s got=%s rc=%s: [%s] %s\n  %s\n' "$want" "$got" "$rc" "$cwd" "$cmd" "$out"; fi
}

check deny  "$P" "codedb word Config"
check deny  "$P" "codedb /repo word Config"
check allow "$P" "codedb word Config | head -40"
check allow "$P" "codedb /repo explain Config"

check deny  "$U" "rg -n foo"
check deny  "$U" "grep -rn foo ."
check deny  "$U" "cd . && rg -n foo"
check allow "$U" "rg -n foo repo/"
check allow "$U" "cd repo && rg -n foo"
check allow "$P" "rg -n foo"

check deny  "$P" "bat -pp long.ts"
check deny  "$P" "cat long.ts"
check deny  "$P" "bat -pp $P/long.ts"
check deny  "$P" "wc -l long.ts && bat -pp long.ts"
check deny  "$P" "bat -pp short.ts long.ts"
check deny  "$P" "cat long.ts | less"
check allow "$P" "bat -pp short.ts"
check allow "$P" "bat -pp --line-range 1:40 long.ts"
check allow "$P" "bat -pp -r 1:40 long.ts"
check allow "$P" "bat -pp -r1:40 long.ts"
check allow "$P" "cat long.ts | head -40"
check allow "$P" "cat long.ts | wc -l"
check allow "$P" "bat -pp long.ts | rg -n 12"
check allow "$P" "bat -pp missing.ts"

check allow "$P" "grep -n cancelled short.ts"
check allow "$P" "rg -n 'a|b|c|d' src/"
check allow "$P" "rg -n -m 40 'a|b|c|d' \$T | head -40"
check allow "$P" $'jj describe -m \'fix: x\ngrep -q exits\''

SEARCH_GUARD_OFF=1 check allow "$P" "codedb word Config"
READ_GUARD_MAX_LINES=500 check allow "$P" "bat -pp long.ts"

printf '%s/%s rows passed\n' "$((n - fail))" "$n"
[ "$fail" -eq 0 ]
