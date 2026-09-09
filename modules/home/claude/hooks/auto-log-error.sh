#!/bin/bash
command -v zigmemo >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
ERROR=$(echo "$INPUT" | jq -r '.tool_error // .stderr // empty' | head -3)
[ -z "$CMD" ] && exit 0
[ -z "$ERROR" ] && exit 0
zigmemo error "$(echo "$CMD" | head -1 | cut -c1-120)" "$(echo "$ERROR" | head -1 | cut -c1-200)" 2>/dev/null
exit 0
