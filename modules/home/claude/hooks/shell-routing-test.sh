#!/bin/bash
HOOK=${1:-$(dirname "$0")/shell-routing.sh}
GUIDE=${2:-$(dirname "$0")/../claude-adapter.md}
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail=0
expect() { if [ "$2" != "$3" ]; then fail=$((fail + 1)); printf 'FAIL %s\n  got:  %s\n  want: %s\n' "$1" "$2" "$3"; fi; }

out=$(printf '{}' | SHELL_ROUTING_GUIDE=$GUIDE bash "$HOOK")
expect "event name" "$(printf '%s' "$out" | jq -r .hookSpecificOutput.hookEventName)" "SessionStart"
ctx=$(printf '%s' "$out" | jq -r .hookSpecificOutput.additionalContext)
case $ctx in *'z DIR && CMD'*'fcp SRC DST'*) ok=yes ;; *) ok=no ;; esac
expect "context carries the z and fcp routes" "$ok" yes
case $ctx in *'**Shell guard**'*) bare=no ;; *) bare=yes ;; esac
expect "context drops the bullet label" "$bare" yes

expect "missing guide emits nothing" "$(printf '{}' | SHELL_ROUTING_GUIDE=$TMP/none bash "$HOOK")" ""
printf '# x\n- **Other**: y\n' >"$TMP/g.md"
expect "guide without the line emits nothing" "$(printf '{}' | SHELL_ROUTING_GUIDE=$TMP/g.md bash "$HOOK")" ""

[ "$fail" -eq 0 ] && echo "shell-routing: all checks passed"
[ "$fail" -eq 0 ]
