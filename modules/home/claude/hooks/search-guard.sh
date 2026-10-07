#!/bin/bash
# search-guard — PreToolUse(Bash) guard for code search. PROTECTIVE ONLY: it never blocks rg/grep/cat as such.
# It blocks the four measured token bombs and says what to run instead. Fail-open on any error.
# Disable: SEARCH_GUARD_OFF=1.  Measured on M4 Pro, ~/devv (65k files, 19k in node_modules):
#   rg at ~/devv root = 1.8 s + floods; `codedb word Config` = 1.7 MB (27k lines); minified lines = 300 KB spills.
[ -n "${SEARCH_GUARD_OFF:-}" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat 2>/dev/null) || exit 0
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -z "$CMD" ] && exit 0
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null); [ -z "$CWD" ] && CWD=$(pwd -P)
UMBRELLA="${SEARCH_GUARD_UMBRELLA:-$HOME/devv}"
deny() { printf '%s\n' "$1" >&2; exit 2; }

# 1. `codedb word X` with no cap: uncapped inverted-index dump (27k lines for `Config`).
if printf '%s' "$CMD" | grep -Eq '(^|[;&|[:space:]])codedb([[:space:]]+[^[:space:]]+)?[[:space:]]+word[[:space:]]' \
   && ! printf '%s' "$CMD" | grep -Eq '\|[[:space:]]*(head|wc|tail|sort|uniq|awk|sed|rg|grep|cut)'; then
  deny "search-guard: 'codedb word' has no result cap (1.7 MB for a common identifier). Use 'codedb <repo> explain SYM' (def + callers), 'codedb <repo> search --max-results 30 TEXT', or 'rg -c PAT <repo>' for counts; or pipe word to '| head -40'."
fi

# 2. rg/grep launched from the umbrella root (~/devv) with no narrower path: 65k files, 1.8 s, node_modules noise.
if [ "$CWD" = "$UMBRELLA" ] && printf '%s' "$CMD" | grep -Eq '(^|;|&&|\|\|)[[:space:]]*(rg|grep|egrep|fgrep)[[:space:]]'; then
  # allow if any arg is a sub-path (a token containing '/' that is not a flag), or a leading `cd DIR &&` re-scopes
  # the command into a repo before rg runs (DIR = '.' or the umbrella itself does not count).
  cdto=$(printf '%s' "$CMD" | sed -nE 's/^[[:space:]]*cd[[:space:]]+([^[:space:];&|]+).*/\1/p')
  rest="$CMD"; [ -n "$cdto" ] && rest=$(printf '%s' "$CMD" | sed -E 's/^[[:space:]]*cd[[:space:]]+[^[:space:];&|]+//')
  case "$cdto" in ""|.|"$UMBRELLA"|"~/devv"|"$HOME/devv") cdto="";; esac
  if [ -z "$cdto" ] && ! printf '%s' "$rest" | grep -Eq '(^|[[:space:]])[^-[:space:]][^[:space:]]*/' ; then
    deny "search-guard: rg/grep at the ~/devv umbrella root scans 65k files (19k in node_modules) in ~1.8 s and floods context. Scope to a repo dir: 'rg -c PAT <repo>/' then 'rg -n PAT <repo>/'."
  fi
fi

# 3. bat (or cat) of a long file with no line range: token bomb. read-guard caps the Read tool at the same height; point at a span.
if printf '%s' "$CMD" | grep -Eq '(^|[;&|[:space:]])(cat|bat)[[:space:]]' \
   && ! printf '%s' "$CMD" | grep -Eq -- '--line-range|(^|[[:space:]])-r([[:space:]]|[0-9:])'; then
  for f in $(printf '%s' "$CMD" | grep -Eo '(^|[[:space:]])(cat|bat)[[:space:]]+[^|;&]*(\|[[:space:]]*[A-Za-z]+)?' \
               | grep -Ev '\|[[:space:]]*(head|tail|rg|grep|wc|jq|cut|awk|sort|uniq)$' \
               | sed -E 's/\|.*$//; s/^[[:space:]]*(cat|bat)[[:space:]]+//' | tr ' ' '\n' | grep -v '^-'); do
    p="$f"; [ "${p#/}" = "$p" ] && p="$CWD/$f"
    if [ -f "$p" ]; then n=$(wc -l < "$p" 2>/dev/null | tr -d " " || echo 0); [ "$n" -gt "${READ_GUARD_MAX_LINES:-300}" ] && deny "search-guard: $f has $n lines. Read a span: 'bat -pp --line-range A:B $f' after 'codedb <repo> outline $f', or the Read tool with offset/limit."; fi
  done
fi
exit 0
