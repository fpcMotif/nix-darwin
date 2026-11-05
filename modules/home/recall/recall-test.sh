#!/bin/bash
# The nix check runs recall from the store, so it passes that path in.
RECALL=${1:-$(dirname "$0")/recall.sh}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
APP=/work/app
export RECALL_CLAUDE_DIR="$tmp/claude" RECALL_CODEX_DIR="$tmp/codex" RECALL_PI_DIR="$tmp/pi"
export RECALL_OMP_DIR="$tmp/omp" RECALL_AGY_HISTORY="$tmp/agy/history.jsonl"
mkdir -p "$RECALL_CLAUDE_DIR/-work-app" "$RECALL_CODEX_DIR/2026/10/01" "$RECALL_PI_DIR/--work-app--" "$RECALL_OMP_DIR/-app" "$tmp/agy"

claude="$RECALL_CLAUDE_DIR/-work-app/c1.jsonl"
jq -cn '{type:"user",isMeta:true,message:{content:"skill body noise"}}' >"$claude"
jq -cn '{type:"user",message:{content:"claude prompt: use port 8443"}}' >>"$claude"
jq -cn '{type:"user",message:{content:[{type:"tool_result",content:"tool noise"}]}}' >>"$claude"
jq -cn '{type:"user",message:{content:"<task-notification> <task-id>bg1</task-id> task noise"}}' >>"$claude"
jq -cn '{type:"user",message:{content:"<command-message>review</command-message> <command-name>/review</command-name> <command-args>check the auth flow</command-args>"}}' >>"$claude"
jq -cn '{type:"assistant",message:{content:[{type:"text",text:"ERR_TLS_CERT in vite.config.ts"}]}}' >>"$claude"

codex="$RECALL_CODEX_DIR/2026/10/01/rollout-x.jsonl"
jq -cn --arg c "$APP" '{type:"session_meta",payload:{cwd:$c}}' >"$codex"
jq -cn '{type:"response_item",payload:{type:"message",role:"user",content:[{type:"input_text",text:"AGENTS.md noise"}]}}' >>"$codex"
jq -cn '{type:"event_msg",payload:{type:"item_completed",item:{type:"UserMessage",content:[{type:"text",text:"codex prompt: drop redis"}]}}}' >>"$codex"
other="$RECALL_CODEX_DIR/2026/10/01/rollout-y.jsonl"
jq -cn '{type:"session_meta",payload:{cwd:"/work/app/sub"}}' >"$other"
jq -cn '{type:"event_msg",payload:{type:"item_completed",item:{type:"UserMessage",content:[{type:"text",text:"subfolder prompt"}]}}}' >>"$other"

for f in "$RECALL_PI_DIR/--work-app--/p1.jsonl" "$RECALL_OMP_DIR/-app/o1.jsonl"; do
  jq -cn --arg c "$APP" '{type:"session",cwd:$c}' >"$f"
done
jq -cn '{type:"message",message:{role:"user",content:[{type:"text",text:"pi prompt: keep bun"}]}}' >>"$RECALL_PI_DIR/--work-app--/p1.jsonl"
jq -cn '{type:"message",message:{role:"user",content:[{type:"text",text:"omp prompt: no docker"}]}}' >>"$RECALL_OMP_DIR/-app/o1.jsonl"

jq -cn --arg c "$APP" '{display:"/model",workspace:$c,conversationId:"g1",type:"slash_command",timestamp:1}' >"$RECALL_AGY_HISTORY"
jq -cn --arg c "$APP" '{display:"agy prompt: dark mode first",workspace:$c,conversationId:"g1",timestamp:1791200000000}' >>"$RECALL_AGY_HISTORY"

touch -d '2026-10-01 10:00' "$claude"
touch -d '2026-10-02 10:00' "$codex" "$other"
touch -d '2026-10-03 10:00' "$RECALL_PI_DIR/--work-app--/p1.jsonl"
touch -d '2026-10-04 10:00' "$RECALL_OMP_DIR/-app/o1.jsonl"

fail=0; n=0
has() {
  n=$((n + 1))
  case "$2" in *"$3"*) ;; *) fail=$((fail + 1)); printf 'FAIL %s: want [%s] in:\n%s\n' "$1" "$3" "$2" ;; esac
}
lacks() {
  n=$((n + 1))
  case "$2" in *"$3"*) fail=$((fail + 1)); printf 'FAIL %s: unwanted [%s] in:\n%s\n' "$1" "$3" "$2" ;; esac
}

out=$(bash "$RECALL" list -C "$APP")
for agent in claude codex pi omp antigravity; do has "list shows $agent" "$out" "$agent"; done
has "list titles by first prompt" "$out" "claude prompt: use port 8443"
lacks "list keeps exact folder" "$out" "subfolder prompt"
first=$(printf '%s\n' "$out" | awk '/^ *1 /{print; exit}')
has "list puts the newest first" "$first" "antigravity"

out=$(bash "$RECALL" brief -C "$APP" -n 5)
for p in "use port 8443" "drop redis" "keep bun" "no docker" "dark mode first"; do has "brief has $p" "$out" "$p"; done
has "brief keeps a slash command's words" "$out" "/review check the auth flow"
lacks "brief drops the command wrapper" "$out" "<command-message>"
for noise in "skill body noise" "tool noise" "task noise" "AGENTS.md noise" "/model"; do lacks "brief drops $noise" "$out" "$noise"; done

out=$(bash "$RECALL" brief -C "$APP" -n 1)
lacks "brief -n 1 stops at one session" "$out" "no docker"

out=$(bash "$RECALL" show 5 -C "$APP")
has "show by number" "$out" "use port 8443"

out=$(bash "$RECALL" grep ERR_TLS -C "$APP")
has "grep finds assistant text" "$out" "ERR_TLS_CERT in vite.config.ts"

out=$(bash "$RECALL" list -C /work/none)
has "empty folder says so" "$out" "no sessions"

printf '%s/%s checks passed\n' "$((n - fail))" "$n"
[ "$fail" -eq 0 ]
