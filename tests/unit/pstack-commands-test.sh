#!/bin/bash
# Every inline code span and shell fenced block in skill text must pass the
# shell guard, so a skill never tells an agent to run a command the hook denies.
# Usage: pstack-commands-test.sh HOOK FILE...
HOOK=$1; shift
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail=0; n=0
check() {
  n=$((n + 1))
  out=$(jq -cn --arg c "$1" --arg d "$TMP" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' | bash "$HOOK" 2>&1 >/dev/null)
  if [ $? -eq 2 ]; then
    fail=$((fail + 1))
    printf 'DENIED: %s\n  %s\n' "$1" "$out"
  fi
}
while IFS= read -r span; do
  check "${span:1:${#span}-2}"
done < <(grep -oh '`[^`]*`' "$@" | sort -u)
awk -v out="$TMP/block" '
  FNR == 1 { inb = 0 }
  /^[[:space:]]*```(sh|bash|zsh|shell)?[[:space:]]*$/ && !inb { inb = 1; k++; next }
  /^[[:space:]]*```[[:space:]]*$/ && inb { inb = 0; close(out "." k); next }
  inb { print > (out "." k) }
' "$@"
for block in "$TMP"/block.*; do
  [ -f "$block" ] && check "$(cat "$block")"
done
echo "$n spans and blocks checked, $fail denied"
[ "$n" -gt 0 ] && [ "$fail" -eq 0 ]
