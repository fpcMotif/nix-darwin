#!/bin/bash
# edit-batch-nudge — PostToolUse(Edit): when this Edit is the Nth consecutive assistant turn whose only
# tool call is one Edit, add context naming the batch form: every independent Edit in one response,
# replace_all for a repeated anchor. Each extra turn is one round trip (~2k tokens). In nix-config
# transcripts 104 of 229 Edits sat in such chains (longest 8). Fail-open. Disable: BATCH_NUDGE_OFF=1.
[ -n "${BATCH_NUDGE_OFF:-}" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat 2>/dev/null) || exit 0
T=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null) || exit 0
[ -f "$T" ] || exit 0

# The current message is usually not in the transcript yet when this fires, and a batch of Edits fires
# once per Edit within a second. A per-session stamp keeps one nudge per message: a second fire inside
# 3 s is the same batch, so the message is not a solo Edit and stays silent.
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // "nosession"' 2>/dev/null)
STATE="${TMPDIR:-/tmp}/edit-batch-nudge"; mkdir -p "$STATE" 2>/dev/null || exit 0
NOW=$(jq -n 'now'); LAST=0
[ -f "$STATE/$SID" ] && read -r LAST < "$STATE/$SID"
printf '%s\n' "$NOW" > "$STATE/$SID"
[ "$(jq -n --argjson a "$NOW" --argjson b "${LAST:-0}" '$a - $b < 3')" = "true" ] && exit 0

TAIL=$(tail -n 400 "$T")
# Trailing run of assistant messages whose tool calls are exactly [Edit]. Lines sharing message.id are
# one message (tool streaming splits a batched response across lines); a human prompt breaks the run.
RUN=$(printf '%s\n' "$TAIL" | jq -rs '
  [ .[]
    | if .type == "assistant" then
        {id: .message.id, tools: [ .message.content[]? | select(.type == "tool_use") | .name ]}
      elif .type == "user" and ((.message.content | type) == "string" or ([.message.content[]? | select(.type == "tool_result")] | length) == 0) then
        {id: (.uuid // "prompt"), tools: ["<prompt>"]}
      else empty end ]
  | reduce .[] as $e ([]; (map(.id) | index($e.id)) as $i | if $i == null then . + [$e] else .[$i].tools += $e.tools end)
  | map(select(.tools | length > 0))
  | reverse
  | map(.tools == ["Edit"])
  | (index(false) // length)' 2>/dev/null) || exit 0
case "$RUN" in ''|*[!0-9]*) exit 0;; esac

# N = consecutive solo-Edit turns including this one: counted when this message is already written,
# presumed solo otherwise (a batch silences itself through the stamp above).
CUR=$(printf '%s' "$INPUT" | jq -r '.tool_use_id // empty' 2>/dev/null)
N=$((RUN + 1))
[ -n "$CUR" ] && printf '%s' "$TAIL" | grep -Fq "\"$CUR\"" && N=$RUN
[ "$N" -lt 2 ] && exit 0
jq -cn --arg n "$N" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: ("batch-nudge: " + $n + " consecutive turns each carrying one Edit. Put every remaining independent Edit for this task in one response, one Edit per site, replace_all: true for a repeated anchor. One round trip per Edit costs about 2k tokens.")}}'
exit 0
