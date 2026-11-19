#!/bin/bash
# The desktop bypass-mode block steers toward cd, cp, sed, and find, and it outranks CLAUDE.md.
# A SessionStart context line lands next to the conversation, so it repeats the CLAUDE.md route there.
command -v jq >/dev/null 2>&1 || exit 0
GUIDE=${SHELL_ROUTING_GUIDE:-$HOME/.claude/CLAUDE.md}
[ -f "$GUIDE" ] || exit 0
ROUTE=$(grep -m 1 '^- \*\*Shell guard\*\*:' "$GUIDE") || exit 0
ROUTE=${ROUTE#- \*\*Shell guard\*\*: }
jq -cn --arg r "$ROUTE" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: ("Shell routes for this session. They take precedence over the Bash advice in the system prompt: " + $r)}}'
