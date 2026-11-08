#!/bin/bash
# Antigravity fails closed on a non-zero exit, so every path prints a decision and exits 0.
allow() { printf '{"decision":"allow"}\n'; exit 0; }
command -v jq >/dev/null 2>&1 || allow
INPUT=$(cat 2>/dev/null) || allow
[ "$(printf '%s' "$INPUT" | jq -r '.toolCall.name // empty' 2>/dev/null)" = run_command ] || allow
CMD=$(printf '%s' "$INPUT" | jq -r '.toolCall.args.CommandLine // empty' 2>/dev/null)
[ -z "$CMD" ] && allow
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // .toolCall.args.Cwd // .workspacePaths[0] // empty' 2>/dev/null)
CLAUDE_PAYLOAD=$(jq -cn --arg c "$CMD" --arg d "$CWD" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}')

for guard in "$@"; do
  [ -f "$guard" ] || continue
  reason=$(printf '%s' "$CLAUDE_PAYLOAD" | bash "$guard" 2>&1 >/dev/null)
  if [ "$?" -eq 2 ]; then
    jq -cn --arg r "$reason" '{decision:"deny",reason:($r
      | gsub("the Edit tool"; "edit_file") | gsub("the Write tool"; "write_file")
      | gsub("Edit tool"; "edit_file") | gsub("Write tool"; "write_file"))}'
    exit 0
  fi
done
allow
