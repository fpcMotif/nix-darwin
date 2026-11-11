#!/bin/bash
# The nix check runs the hooks from the store, so it passes their paths in.
HOOK=${1:-$(dirname "$0")/agy-guard.sh}
SHELL_GUARD=${2:-$(dirname "$0")/../claude/hooks/shell-guard.sh}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
printf '#!/bin/bash\nexit 1\n' >"$tmp/broken.sh"
printf '#!/bin/bash\necho "no ls here: use the Edit tool or the Write tool" >&2; exit 2\n' >"$tmp/deny-all.sh"
chmod +x "$tmp/broken.sh" "$tmp/deny-all.sh"
unset EDIT_GUARD_OFF
fail=0; n=0
# Antigravity reads only the stdout JSON, and a non-zero exit fails closed, so rc must stay 0.
check() {
  want=$1; tool=$2; cmd=$3; shift 3; n=$((n + 1))
  out=$(jq -cn --arg t "$tool" --arg c "$cmd" --arg w "$tmp" \
    '{toolCall:{name:$t,args:{CommandLine:$c}},workspacePaths:[$w],conversationId:"c",stepIdx:1}' \
    | bash "$HOOK" "${@:-$SHELL_GUARD}"); rc=$?
  got=$(printf '%s' "$out" | jq -r '.decision' 2>/dev/null)
  if [ "$rc" -ne 0 ] || [ "$got" != "$want" ]; then
    fail=$((fail + 1)); printf 'FAIL want=%s got=%s rc=%s: %s %s\n  %s\n' "$want" "$got" "$rc" "$tool" "$cmd" "$out"
  fi
  LAST=$out
}

check deny  run_command "sed -i '' 's/a/b/' notes.txt"
check deny  run_command "cat <<'EOF' > notes.txt
hello
EOF"
check allow run_command "ls -la"
check allow edit_file   ""
check allow run_command "ls" "$tmp/broken.sh"
check deny  run_command "ls" "$tmp/broken.sh" "$tmp/deny-all.sh"
reason=$(printf '%s' "$LAST" | jq -r '.reason')
case $reason in
  *edit_file*write_file*) ;;
  *) fail=$((fail + 1)); printf 'FAIL reason names Claude tools, not edit_file and write_file: %s\n' "$reason" ;;
esac
n=$((n + 1))

printf '%d checks, %d failed\n' "$n" "$fail"
[ "$fail" -eq 0 ]
