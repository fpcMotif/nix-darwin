#!/bin/bash
[ -n "${SEARCH_GUARD_OFF:-}" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat 2>/dev/null) || exit 0
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -z "$CMD" ] && exit 0
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null); [ -z "$CWD" ] && CWD=$(pwd -P)
UMBRELLA="${SEARCH_GUARD_UMBRELLA:-$HOME/devv}"
deny() { printf '%s\n' "$1" >&2; exit 2; }

command_has() { printf '%s' "$CMD" | grep -Eq -- "$1"; }
has_subpath_arg() { printf '%s' "$1" | grep -Eq '(^|[[:space:]])[^-[:space:]][^[:space:]]*/'; }

unranged_read_targets() {
  printf '%s' "$CMD" | grep -Eo '(^|[[:space:]])(cat|bat)[[:space:]]+[^|;&]*(\|[[:space:]]*[A-Za-z]+)?' \
    | grep -Ev '\|[[:space:]]*(head|tail|rg|grep|wc|jq|cut|awk|sort|uniq)$' \
    | sed -E 's/\|.*$//; s/^[[:space:]]*(cat|bat)[[:space:]]+//' | tr ' ' '\n' | grep -v '^-'
}

# Measured on M4 Pro in ~/devv: `codedb word Config` returns 1.7 MB (27k lines).
if command_has '(^|[;&|[:space:]])codedb([[:space:]]+[^[:space:]]+)?[[:space:]]+word[[:space:]]' \
   && ! command_has '\|[[:space:]]*(head|wc|tail|sort|uniq|awk|sed|rg|grep|cut)'; then
  deny "search-guard: 'codedb word' has no result cap (1.7 MB for a common identifier). Use 'codedb <repo> explain SYM' (def + callers), 'codedb <repo> search --max-results 30 TEXT', or 'rg -c PAT <repo>' for counts; or pipe word to '| head -40'."
fi

# Measured on M4 Pro: rg at the ~/devv root scans 65k files, 19k in node_modules, in 1.8 s.
if [ "$CWD" = "$UMBRELLA" ] && command_has '(^|;|&&|\|\|)[[:space:]]*(rg|grep|egrep|fgrep)[[:space:]]'; then
  cd_target=$(printf '%s' "$CMD" | sed -nE 's/^[[:space:]]*cd[[:space:]]+([^[:space:];&|]+).*/\1/p')
  after_cd="$CMD"; [ -n "$cd_target" ] && after_cd=$(printf '%s' "$CMD" | sed -E 's/^[[:space:]]*cd[[:space:]]+[^[:space:];&|]+//')
  case "$cd_target" in ""|.|"$UMBRELLA"|"~/devv"|"$HOME/devv") cd_target="";; esac
  if [ -z "$cd_target" ] && ! has_subpath_arg "$after_cd"; then
    deny "search-guard: rg/grep at the ~/devv umbrella root scans 65k files (19k in node_modules) in ~1.8 s and floods context. Scope to a repo dir: 'rg -c PAT <repo>/' then 'rg -n PAT <repo>/'."
  fi
fi

if command_has '(^|[;&|[:space:]])(cat|bat)[[:space:]]' \
   && ! command_has '--line-range|(^|[[:space:]])-r([[:space:]]|[0-9:])'; then
  for f in $(unranged_read_targets); do
    path="$f"; [ "${path#/}" = "$path" ] && path="$CWD/$f"
    [ -f "$path" ] || continue
    lines=$(wc -l < "$path" 2>/dev/null | tr -d " " || echo 0)
    [ "$lines" -gt "${READ_GUARD_MAX_LINES:-300}" ] && deny "search-guard: $f has $lines lines. Read a span: 'bat -pp --line-range A:B $f' after 'codedb <repo> outline $f', or the Read tool with offset/limit."
  done
fi
exit 0
