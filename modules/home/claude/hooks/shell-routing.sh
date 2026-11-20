#!/bin/bash
# The desktop bypass-mode block steers toward cd, cp, sed, and find, and it outranks CLAUDE.md.
# A SessionStart context line lands next to the conversation, so it repeats the CLAUDE.md route there.
command -v jq >/dev/null 2>&1 || exit 0
GUIDE=${SHELL_ROUTING_GUIDE:-$HOME/.claude/CLAUDE.md}
LABEL='- **Shell guard**: '
ROUTE=$(grep -s -m 1 -F -- "$LABEL" "$GUIDE") || exit 0
ROUTE=${ROUTE#"$LABEL"}
jq -cn --arg r "$ROUTE" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: ("Shell routes for this session. They take precedence over the Bash advice in the system prompt: " + $r)}}'
