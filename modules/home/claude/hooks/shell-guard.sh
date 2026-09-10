#!/bin/bash
# shell-guard — PreToolUse(Bash): routes Python to uv, file changes to the Edit/Write tools, and file
# reads to the tooling table in CLAUDE.md (bat -pp --line-range, rg, fd).
# The desktop bypass-mode system prompt steers the model toward heredocs, sed -i, and inline python for
# file changes; measured in transcripts those paths errored 4-38% of the time against 0-1.5% for Edit,
# and 33 of 44 inline python edits had no guard against a silently missed anchor (str.replace no-op).
# Each deny names the replacement. Fail-open on any error.
# Disable a group: UV_GUARD_OFF=1 (python), EDIT_GUARD_OFF=1 (file changes), TOOL_GUARD_OFF=1 (cat/sed/find).
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat 2>/dev/null) || exit 0
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -z "$CMD" ] && exit 0
deny() { printf '%s\n' "$1" >&2; exit 2; }

# BODY = the command with heredoc bodies removed, so text inside a document never reads as a command.
BODY=$(printf '%s\n' "$CMD" | awk '
  inhd { line=$0; sub(/^\t+/, "", line); if (line == term) inhd=0; next }
  match($0, /<<-?[[:space:]]*["'"'"']?[A-Za-z_][A-Za-z0-9_]*/) {
    term=substr($0, RSTART, RLENGTH); sub(/<<-?[[:space:]]*["'"'"']?/, "", term); inhd=1; print; next }
  { print }')

# A command position: line start, or after ; && || | ( $( `, with wrappers and VAR=x prefixes stripped.
segments() {
  printf '%s\n' "$BODY" | awk '{ gsub(/&&|\|\||\||;|\$\(|`|\(/, "\n"); print }' \
    | sed -E 's/^[[:space:]]+//; s/^((sudo|time|nohup|exec|command|env|xargs)[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*//'
}

if [ -z "${EDIT_GUARD_OFF:-}" ]; then
  # 1. Inline code (stdin heredoc or -c) that writes a file: an unanchored str.replace edits nothing and reports success.
  if printf '%s' "$CMD" | grep -Eq '<<|[[:space:]]-c[[:space:]]|[[:space:]]-e[[:space:]]' \
     && printf '%s' "$CMD" | grep -Eq "open\([^)]*['\"][wax]|write_text\(|writelines\(|\.write\(|writeFile"; then
    deny "shell-guard: change a file with the Edit tool (exact old_string -> new_string; it fails loudly on a missed anchor, replace_all for every occurrence). Create a file with the Write tool. Inline scripts that call open(...,'w') or .write() are denied."
  fi

  # 2. sed -i / perl -i: BSD sed flags differ, and the edit is unreviewable before it lands.
  if printf '%s' "$BODY" | grep -Eq '(^|[;&|(`[:space:]])(sed[[:space:]]+(-[a-zA-Z]*i|--in-place)|perl[[:space:]]+-[a-zA-Z]*i)'; then
    deny "shell-guard: in-place sed/perl is denied (16-38% error rate in your transcripts). Use the Edit tool: old_string -> new_string, replace_all: true for every occurrence."
  fi

  # 3. A heredoc redirected into a file (cat > f <<EOF, cat <<EOF > f, tee f <<EOF): the content is authored in the command.
  if printf '%s' "$CMD" | grep -Eq '<<' \
     && printf '%s' "$BODY" | grep -E '<<' | grep -Eq '(>>?[[:space:]]*[^&[:space:]>]|(^|[;&|(`[:space:]])tee[[:space:]]+(-a[[:space:]]+)?[^-[:space:]])' \
     && ! printf '%s' "$BODY" | grep -E '<<' | grep -Eq '>>?[[:space:]]*/dev/null'; then
    deny "shell-guard: create the file with the Write tool (content lands verbatim, no heredoc quoting). Change lines with the Edit tool. A heredoc redirected into a file is denied."
  fi

  # 4. echo/printf of literal text into a file (> or >>): the model authored the text, so Write or Edit carries it.
  if printf '%s' "$BODY" | grep -Eq '(^|[;&|(`[:space:]])(echo|printf)[[:space:]][^|;&]*>>?[[:space:]]*[^&[:space:]>/][^[:space:]]*' \
     || printf '%s' "$BODY" | grep -Eq '(^|[;&|(`[:space:]])(echo|printf)[[:space:]][^|;&]*>>?[[:space:]]*/(Users|home|private|tmp|var|opt|etc)/'; then
    deny "shell-guard: append with the Edit tool (old_string = the current last line, new_string = that line plus the addition) or create the file with the Write tool. echo/printf into a file is denied."
  fi
fi

# 5. Per command position: bare python/pip (uv group) and cat/sed/find (tool group).
while IFS= read -r seg; do
  case "$seg" in
    python|python[[:space:]]*|python[23]|python[23][[:space:].]*|*/python|*/python[[:space:]]*|*/python[23]*|pip|pip[[:space:]]*|pip3*|virtualenv*|pipenv*|poetry*)
      [ -z "${UV_GUARD_OFF:-}" ] && deny "shell-guard: Python runs through uv. Script: 'uv run script.py' (deps in '# /// script' metadata). Stdin: uv run - <<'PY'. One-liner: uv run python -c '...'. Extra dep: 'uv run --with PKG ...'. Install: 'uv add PKG' (project) or 'uv pip install PKG'. Tools: 'uvx ty check', 'ruff check --fix . && ruff format .'." ;;
    cat|cat[[:space:]]*)
      case "$seg" in *"<<"*) ;; *) [ -z "${TOOL_GUARD_OFF:-}" ] && deny "shell-guard: read a span with 'bat -pp --line-range A:B FILE' (a short file: 'bat -pp FILE'); a JSON file with 'jq'. cat is denied." ;; esac ;;
    sed|sed[[:space:]]*)
      [ -z "${TOOL_GUARD_OFF:-}" ] && deny "shell-guard: sed is denied. A span: 'bat -pp --line-range A:B FILE'. A stream rewrite: 'rg -o PAT -r REPL' or awk. A file change: the Edit tool." ;;
    find|find[[:space:]]*)
      [ -z "${TOOL_GUARD_OFF:-}" ] && deny "shell-guard: find is denied. Use 'fd PATTERN [DIR]' (-e EXT, -t f|d, -H for hidden)." ;;
    perl|perl[[:space:]]*|awk[[:space:]]-i*)
      [ -z "${TOOL_GUARD_OFF:-}" ] && deny "shell-guard: perl one-liners are denied. A stream rewrite: 'rg -o PAT -r REPL'; structured data: jq; a file change: the Edit tool; a rule across files: 'sg -p PAT -r REPL --lang X DIR' then -U; anything larger: a script file run with 'uv run'." ;;
  esac
done <<EOF
$(segments)
EOF
exit 0
