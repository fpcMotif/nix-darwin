#!/bin/bash
# A summary drops exact errors, paths, and user corrections. The transcript
# keeps them, so a reset hands Claude its path instead of a summary.
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat 2>/dev/null) || exit 0
field() { printf '%s' "$INPUT" | jq -r --arg k "$1" '.[$k] // empty' 2>/dev/null; }
STATE_DIR="${CONTEXT_HANDOFF_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/claude-handoff}"
CWD=$(field cwd); [ -z "$CWD" ] && exit 0
KEY="$STATE_DIR/$(printf '%s' "$CWD" | cksum | cut -d' ' -f1)"

case "$1" in
  save)
    TRANSCRIPT=$(field transcript_path)
    [ -f "$TRANSCRIPT" ] || exit 0
    mkdir -p "$STATE_DIR" && printf '%s\n' "$TRANSCRIPT" >"$KEY"
    ;;
  resume)
    case "$(field source)" in
      clear)
        [ -f "$KEY" ] || exit 0
        TRANSCRIPT=$(cat "$KEY")
        LEAD="This session continues the previous session in this folder. Its full record is $TRANSCRIPT."
        ;;
      compact)
        TRANSCRIPT=$(field transcript_path)
        LEAD="A summary replaced the earlier turns. The full record is still $TRANSCRIPT."
        ;;
      *) exit 0 ;;
    esac
    [ -f "$TRANSCRIPT" ] || exit 0
    jq -cn --arg lead "$LEAD" --arg t "$TRANSCRIPT" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: ($lead + "\n\nThe record is JSONL, one event per line. It holds every user correction, decision, rejected approach, exact error string, and file path.\n\n1. Before the first task, read the user'"'"'s earlier messages, since a correction there still binds:\n   jq -r '"'"'select(.type==\"user\" and (.isMeta|not)) | .message.content | if type==\"string\" then . else (map(select(.type==\"text\").text) | join(\"\\n\")) end | select(length>0) | .[0:600]'"'"' " + $t + " | tail -n 60\n2. When the work or the user refers to something earlier, retrieve it before acting:\n   rg -o '"'"'.{0,300}TERM.{0,300}'"'"' " + $t + " | tail -n 20\n\nA hit is a receipt of a past event. Check live state (files, git, tests) before relying on it.")}}'
    ;;
esac
exit 0
