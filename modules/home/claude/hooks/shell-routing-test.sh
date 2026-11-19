#!/bin/bash
HOOK=${1:-$(dirname "$0")/shell-routing.sh}
GUIDE=${2:-$(dirname "$0")/../claude-adapter.md}
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail=0
expect() { if [ "$2" != "$3" ]; then fail=$((fail + 1)); printf 'FAIL %s\n  got:  %s\n  want: %s\n' "$1" "$2" "$3"; fi; }

out=$(printf '{}' | SHELL_ROUTING_GUIDE=$GUIDE bash "$HOOK")
expect "event name" "$(printf '%s' "$out" | jq -r .hookSpecificOutput.hookEventName)" "SessionStart"
expect "context carries the z and fcp routes without the bullet label" \
  "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext | contains("z DIR && CMD") and contains("fcp SRC DST") and (contains("**Shell guard**") | not)')" true

expect "missing guide emits nothing" "$(printf '{}' | SHELL_ROUTING_GUIDE=$TMP/none bash "$HOOK")" ""
printf '# x\n- **Other**: y\n' >"$TMP/g.md"
expect "guide without the line emits nothing" "$(printf '{}' | SHELL_ROUTING_GUIDE=$TMP/g.md bash "$HOOK")" ""

[ "$fail" -eq 0 ] || exit 1
echo "shell-routing: all checks passed"
