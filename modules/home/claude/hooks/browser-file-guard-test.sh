#!/bin/bash
HOOK=${1:-$(dirname "$0")/browser-file-guard.sh}
unset BROWSER_FILE_GUARD_OFF
fail=0; n=0
check() {
  want=$1; input=$2; n=$((n + 1))
  out=$(printf '%s' "$input" | bash "$HOOK" 2>&1 >/dev/null); rc=$?
  got=allow; [ "$rc" -eq 2 ] && got=deny
  if [ "$got" != "$want" ]; then fail=$((fail + 1)); printf 'FAIL want=%s got=%s rc=%s: %s\n  %s\n' "$want" "$got" "$rc" "$input" "$out"; fi
}

check deny  '{"tool_name":"mcp__Claude_Browser__preview_start","tool_input":{"url":"file:///private/tmp/claude-501/x/scratchpad/flow.html"}}'
check deny  '{"tool_name":"mcp__Claude_Browser__navigate","tool_input":{"url":"file:///Users/me/page.html"}}'
check deny  '{"tool_name":"mcp__Claude_Browser__navigate","tool_input":{"url":"FILE:///Users/me/page.html"}}'
check deny  '{"tool_name":"mcp__Claude_Browser__browser_batch","tool_input":{"actions":[{"name":"computer","input":{"action":"screenshot"}},{"name":"navigate","input":{"url":"file:///tmp/a.html"}}]}}'
check allow '{"tool_name":"mcp__Claude_Browser__preview_start","tool_input":{"url":"http://localhost:5173"}}'
check allow '{"tool_name":"mcp__Claude_Browser__preview_start","tool_input":{"name":"dev"}}'
check allow '{"tool_name":"mcp__Claude_Browser__navigate","tool_input":{"url":"back"}}'
check allow '{"tool_name":"mcp__Claude_Browser__navigate","tool_input":{"url":"https://example.com/file:///x"}}'
check allow '{"tool_name":"mcp__Claude_Browser__browser_batch","tool_input":{"actions":[{"name":"navigate","input":{"url":"https://example.com"}}]}}'
check allow 'not json'
BROWSER_FILE_GUARD_OFF=1 check allow '{"tool_name":"mcp__Claude_Browser__navigate","tool_input":{"url":"file:///tmp/a.html"}}'

printf '%s/%s rows passed\n' "$((n - fail))" "$n"
[ "$fail" -eq 0 ]
