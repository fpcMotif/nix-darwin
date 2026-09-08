#!/bin/bash
# PreToolUse(Read): a whole-file Read of a long file is the single largest token sink measured in agent trials
# (haiku read 5 whole files of 140-250 lines per task and used ~10% of the lines). Deny a limit-less Read of a
# file longer than READ_GUARD_MAX_LINES (default 200) and say how to read a span. Escape hatch: pass offset+limit.
# Fail-open on any error. Disable: SEARCH_GUARD_OFF=1.
[ -n "${SEARCH_GUARD_OFF:-}" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat 2>/dev/null) || exit 0
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
[ -z "$FILE" ] || [ ! -f "$FILE" ] && exit 0
LIMIT=$(printf '%s' "$INPUT" | jq -r '.tool_input.limit // empty' 2>/dev/null)
[ -n "$LIMIT" ] && exit 0
case "$FILE" in "$HOME"/.claude/*|/private/tmp/*|/tmp/*|*.md|*.json|*.toml|*.yaml|*.yml|*.lock) exit 0;; esac
MAX="${READ_GUARD_MAX_LINES:-200}"
N=$(wc -l < "$FILE" 2>/dev/null | tr -d ' ') || exit 0
[ "$N" -le "$MAX" ] && exit 0
ROOT=$(git -C "$(dirname "$FILE")" rev-parse --show-toplevel 2>/dev/null || dirname "$FILE")
REL="${FILE#$ROOT/}"
printf 'read-guard: %s has %s lines. Locate first, then read a span: `codedb %s outline %s` (symbols + line numbers), then Read with offset/limit, or `codedb %s read %s -L A-B`. If you really need the whole file, Read with offset=1 limit=%s.\n' "$REL" "$N" "$ROOT" "$REL" "$ROOT" "$REL" "$N" >&2
exit 2
