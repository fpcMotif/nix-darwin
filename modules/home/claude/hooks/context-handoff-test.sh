#!/bin/bash
# The nix check runs the hook from the store, so it passes that path in.
HOOK=${1:-$(dirname "$0")/context-handoff.sh}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export CONTEXT_HANDOFF_DIR="$tmp/state"
OLD="$tmp/old.jsonl"
NEW="$tmp/new.jsonl"
printf '{"type":"user"}\n' >"$OLD"
printf '{"type":"user"}\n' >"$NEW"
fail=0; n=0
run() { mode=$1; shift; jq -cn "$@" | bash "$HOOK" "$mode"; }
expect() {
  label=$1; got=$2; want=$3; n=$((n + 1))
  case "$got" in
    *"$want"*) ;;
    *) fail=$((fail + 1)); printf 'FAIL %s: want [%s] in [%s]\n' "$label" "$want" "$got" ;;
  esac
}
expect_empty() {
  n=$((n + 1))
  [ -z "$2" ] || { fail=$((fail + 1)); printf 'FAIL %s: want no output, got [%s]\n' "$1" "$2"; }
}

out=$(run resume --arg t "$NEW" '{source:"clear",cwd:"/p",transcript_path:$t}')
expect_empty "clear with nothing saved" "$out"

run save --arg t "$OLD" '{reason:"clear",cwd:"/p",transcript_path:$t}'
out=$(run resume --arg t "$NEW" '{source:"clear",cwd:"/p",transcript_path:$t}')
expect "clear names the old transcript" "$out" "$OLD"
expect "clear emits SessionStart context" "$(printf '%s' "$out" | jq -r .hookSpecificOutput.hookEventName)" "SessionStart"

out=$(run resume --arg t "$NEW" '{source:"clear",cwd:"/other",transcript_path:$t}')
expect_empty "another folder gets no handoff" "$out"

out=$(run resume --arg t "$NEW" '{source:"compact",cwd:"/p",transcript_path:$t}')
expect "compact names its own transcript" "$out" "$NEW"

rm "$OLD"
out=$(run resume --arg t "$NEW" '{source:"clear",cwd:"/p",transcript_path:$t}')
expect_empty "a deleted transcript gets no handoff" "$out"

printf '%s/%s checks passed\n' "$((n - fail))" "$n"
[ "$fail" -eq 0 ]
