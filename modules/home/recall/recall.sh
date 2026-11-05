#!/bin/bash
# Each agent keeps its own session files. recall reads them in place, so a new
# session in any agent can pull earlier prompts without a summary or a server.
set -euo pipefail

CLAUDE_DIR=${RECALL_CLAUDE_DIR:-$HOME/.claude/projects}
CODEX_DIR=${RECALL_CODEX_DIR:-$HOME/.codex/sessions}
PI_DIR=${RECALL_PI_DIR:-$HOME/.pi/agent/sessions}
OMP_DIR=${RECALL_OMP_DIR:-$HOME/.omp/agent/sessions}
AGY_HISTORY=${RECALL_AGY_HISTORY:-$HOME/.gemini/antigravity-cli/history.jsonl}

usage() {
  cat <<'EOF'
recall: earlier agent sessions for this folder (Claude Code, Codex, pi, omp, Antigravity)

  recall [list] [-n N]     sessions, newest first (default 10)
  recall brief [-n N]      user prompts of the N newest sessions (default 3)
  recall show REF          every user prompt of one session
  recall grep REGEX [REF]  capped hits across sessions, prompts and replies

REF is a number from `recall list` or a session file path.
-C DIR reads another folder. Session 1 can be the one now running.
EOF
}

collapse='gsub("\\s+"; " ") | sub("^ "; "") | select(length > 0)'
text_of='if type == "string" then . else (map(select(.type == "text" or .type == "input_text") | .text) | join(" ")) end'

sessions() {
  local slug f
  slug=$(printf '%s' "$CWD" | tr -c 'A-Za-z0-9' '-')
  for f in "$CLAUDE_DIR/$slug"/*.jsonl; do
    [ -f "$f" ] && printf '%s\tclaude\t%s\n' "$(stat -c %Y "$f")" "$f"
  done
  local agent root
  for agent in codex pi omp; do
    case $agent in codex) root=$CODEX_DIR ;; pi) root=$PI_DIR ;; omp) root=$OMP_DIR ;; esac
    [ -d "$root" ] || continue
    rg --no-config -l -F -m1 -g '*.jsonl' "\"cwd\":\"$CWD\"" "$root" 2>/dev/null \
      | while IFS= read -r f; do printf '%s\t%s\t%s\n' "$(stat -c %Y "$f")" "$agent" "$f"; done || true
  done
  [ -f "$AGY_HISTORY" ] && jq -r --arg c "$CWD" \
    'select(.workspace == $c and .conversationId and .type != "slash_command")
     | [(.timestamp / 1000 | floor), .conversationId] | @tsv' "$AGY_HISTORY" 2>/dev/null \
    | awk -F'\t' '{ if ($1 > t[$2]) t[$2] = $1 } END { for (id in t) printf "%s\tantigravity\t%s\n", t[id], id }'
  true
}

prompts() {
  local agent=$1 ref=$2 max=$3
  case $agent in
    claude) jq -r --argjson m "$max" "select(.type == \"user\" and (.isMeta | not)) | .message.content | $text_of
      | select(startswith(\"<task-notification>\") | not)
      | if test(\"<command-name>\") then
          (capture(\"<command-name>(?<n>[^<]*)</command-name>\").n) + \" \" + ((capture(\"<command-args>(?<a>[^<]*)\").a) // \"\")
        else . end | $collapse | .[0:\$m]" "$ref" ;;
    codex) jq -r --argjson m "$max" "select(.type == \"event_msg\") | .payload
      | if .type == \"item_completed\" and .item.type == \"UserMessage\" then (.item.content | $text_of)
        elif .type == \"user_message\" then .message else empty end | $collapse | .[0:\$m]" "$ref" ;;
    pi | omp) jq -r --argjson m "$max" "select(.type == \"message\" and .message.role == \"user\") | .message.content | $text_of | $collapse | .[0:\$m]" "$ref" ;;
    antigravity) jq -r --arg c "$CWD" --arg id "$ref" --argjson m "$max" "select(.workspace == \$c and .conversationId == \$id and .type != \"slash_command\") | .display | $collapse | .[0:\$m]" "$AGY_HISTORY" ;;
  esac 2>/dev/null || true
}

when() { date -d "@$1" '+%Y-%m-%d %H:%M'; }
where() { if [ "$1" = antigravity ]; then printf 'antigravity-cli conversation %s' "$2"; else printf '%s' "$2"; fi; }

resolve() {
  local row
  if [[ $1 =~ ^[0-9]+$ ]]; then
    row=$(printf '%s\n' "$SESSIONS" | awk -F'\t' -v n="$1" 'NR == n { print $2 "\t" $3 }')
    [ -n "$row" ] || { echo "recall: no session $1 in $CWD" >&2; exit 1; }
    printf '%s\n' "$row"
  else
    case $1 in
      "$CLAUDE_DIR"/*) printf 'claude\t%s\n' "$1" ;;
      "$CODEX_DIR"/*) printf 'codex\t%s\n' "$1" ;;
      "$PI_DIR"/*) printf 'pi\t%s\n' "$1" ;;
      "$OMP_DIR"/*) printf 'omp\t%s\n' "$1" ;;
      *) echo "recall: unknown session $1" >&2; exit 1 ;;
    esac
  fi
}

cmd=list
case ${1:-} in list | brief | show | grep) cmd=$1; shift ;; -h | --help | help) usage; exit 0 ;; esac
CWD=$PWD; count=""; args=()
while [ $# -gt 0 ]; do
  case $1 in
    -C) CWD=${2%/}; shift 2 ;;
    -n) count=$2; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) args+=("$1"); shift ;;
  esac
done

SESSIONS=$(sessions | sort -t$'\t' -k1,1nr)
if [ -z "$SESSIONS" ]; then echo "recall: no sessions for $CWD"; exit 0; fi

case $cmd in
  list)
    i=0
    while IFS=$'\t' read -r epoch agent ref; do
      i=$((i + 1)); [ "$i" -gt "${count:-10}" ] && break
      title=$(prompts "$agent" "$ref" 90 | head -n 1)
      printf '%3d  %s  %-11s %s\n     %s\n' "$i" "$(when "$epoch")" "$agent" "${title:-(no prompt)}" "$(where "$agent" "$ref")"
    done <<<"$SESSIONS"
    ;;
  brief)
    i=0
    while IFS=$'\t' read -r epoch agent ref; do
      i=$((i + 1)); [ "$i" -gt "${count:-3}" ] && break
      printf '## %d. %s, %s, %s\n' "$i" "$agent" "$(when "$epoch")" "$(where "$agent" "$ref")"
      prompts "$agent" "$ref" 400 | tail -n 20 | awk '{ print "- " $0 }'
      echo
    done <<<"$SESSIONS"
    echo "More: recall show N (every prompt), recall grep REGEX (exact errors, paths, decisions)."
    ;;
  show)
    [ ${#args[@]} -ge 1 ] || { usage >&2; exit 2; }
    IFS=$'\t' read -r agent ref < <(resolve "${args[0]}")
    prompts "$agent" "$ref" 4000 | awk '{ print "- " $0 }'
    ;;
  grep)
    [ ${#args[@]} -ge 1 ] || { usage >&2; exit 2; }
    pattern=${args[0]}
    if [ ${#args[@]} -ge 2 ]; then
      targets=$(resolve "${args[1]}")
    else
      targets=$(printf '%s\n' "$SESSIONS" | cut -f2,3)
    fi
    while IFS=$'\t' read -r agent ref; do
      if [ "$agent" = antigravity ]; then
        hits=$(prompts antigravity "$ref" 4000 | rg --no-config -i -o ".{0,150}${pattern}.{0,150}" | tail -n 10 || true)
      else
        hits=$(rg --no-config -i -o -N ".{0,150}${pattern}.{0,150}" "$ref" 2>/dev/null | tail -n 10 || true)
      fi
      [ -n "$hits" ] && printf '## %s %s\n%s\n\n' "$agent" "$(where "$agent" "$ref")" "$hits"
    done <<<"$targets"
    ;;
esac
