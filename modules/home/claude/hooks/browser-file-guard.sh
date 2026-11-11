#!/bin/bash
[ -n "${BROWSER_FILE_GUARD_OFF:-}" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat 2>/dev/null) || exit 0
URLS=$(printf '%s' "$INPUT" | jq -r '[.tool_input.url?, (.tool_input.actions[]?.input.url?)] | map(select(type == "string")) | .[]' 2>/dev/null) || exit 0
if printf '%s\n' "$URLS" | grep -Eqi '^file:'; then
  printf '%s\n' "browser-file-guard: the built-in browser pane refuses most file:// pages (18 sessions hit \"couldn't open file://\"). To show a local HTML page, publish it with Artifact or send it with SendUserFile and display \"render\". For a visual check, run the skill's own checker (archify visual-check) or agent-browser on the file." >&2
  exit 2
fi
exit 0
