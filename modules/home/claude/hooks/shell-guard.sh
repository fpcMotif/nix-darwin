#!/bin/bash
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat 2>/dev/null) || exit 0
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -z "$CMD" ] && exit 0
deny() { printf '%s\n' "$1" >&2; exit 2; }

CMD_WITHOUT_HEREDOCS=$(printf '%s\n' "$CMD" | awk '
  in_heredoc { line=$0; sub(/^\t+/, "", line); if (line == term) in_heredoc=0; next }
  match($0, /<<-?[[:space:]]*["'"'"']?[A-Za-z_][A-Za-z0-9_]*/) {
    term=substr($0, RSTART, RLENGTH); sub(/<<-?[[:space:]]*["'"'"']?/, "", term); in_heredoc=1; print; next }
  { print }')

command_segments() {
  printf '%s\n' "$CMD_WITHOUT_HEREDOCS" | awk -v q="'" -v blank="${1:-}" '
    { s = s $0 "\n" }
    END {
      n = length(s); depth = 0; nest[0] = "N"; prev = "\n"
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1); pair = substr(s, i, 2)
        if (nest[depth] == "D") {
          if (c == "\\") { printf "%s", (blank ? "__" : pair); i++ }
          else if (c == "\"") { depth--; printf "%s", c }
          else if (pair == "$(") { nest[++depth] = "P"; printf "\n"; i++ }
          else if (c == "`") { nest[++depth] = "B"; printf "\n" }
          else printf "%s", (blank ? "_" : c == "\n" ? " " : c)
          continue
        }
        if (c == "\\") { printf "%s", (blank ? "\\_" : pair); i++ }
        else if (c == q || pair == "$" q) {
          j = i + (c == q ? 1 : 2)
          while (j <= n && substr(s, j, 1) != q) j += (c != q && substr(s, j, 1) == "\\") ? 2 : 1
          t = substr(s, i, j - i + 1); gsub(/\n/, " ", t); if (blank) gsub(/./, "_", t); printf "%s", t; i = j
        }
        else if (c == "\"") { nest[++depth] = "D"; printf "%s", c }
        else if (c == "#" && prev ~ /[[:space:];&|(`]/) { while (i < n && substr(s, i + 1, 1) != "\n") i++ }
        else if (pair == "&&" || pair == "||" || pair == "$(") { if (pair == "$(") nest[++depth] = "P"; printf "\n"; i++ }
        else if (c == "|" || c == ";") printf "\n"
        else if (c == "(") { nest[++depth] = "P"; printf "\n" }
        else if (c == ")" && nest[depth] == "P") { depth--; printf "%s", c }
        else if (c == "`" && nest[depth] == "B") { depth--; printf "%s", c }
        else if (c == "`") { nest[++depth] = "B"; printf "\n" }
        else printf "%s", c
        prev = c
      }
    }' \
    | sed -E 's/^[[:space:]]+//; s/^((sudo|time|nohup|exec|command|env|xargs)[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*//'
}

# A str.replace whose anchor is missing edits nothing and still reports success.
# In transcripts, 33 of 44 inline python edits had no check for that.
inline_code_writes_file() {
  printf '%s' "$CMD" | grep -Eq '<<|[[:space:]]-c[[:space:]]|[[:space:]]-e[[:space:]]' \
    && printf '%s' "$CMD" | grep -Eq "open\([^)]*,[[:space:]]*(mode[[:space:]]*=[[:space:]]*)?['\"][wax]|write_text\(|writelines\(|\.write\(|writeFile"
}

# BSD sed flags differ, and the edit is unreviewable before it lands.
uses_in_place_sed() {
  printf '%s' "$CMD_WITHOUT_HEREDOCS" | grep -Eq '(^|[;&|(`[:space:]])sed[[:space:]]+(-[a-zA-Z]*i|--in-place)'
}

heredoc_writes_file() {
  printf '%s' "$CMD" | grep -Eq '<<' \
    && command_segments blank-quoted | grep -E '^(cat|tee)([[:space:]]|$)' | grep -E '<<' \
       | sed -E 's#[0-9]*>>?[[:space:]]*/dev/null##g' \
       | grep -Eq '(>>?[[:space:]]*[^&[:space:]>]|^tee[[:space:]]+(-a[[:space:]]+)?[^-[:space:]<])'
}

echo_writes_file() {
  command_segments blank-quoted | grep -Eq '(^|[&[:space:]])(echo|printf)[[:space:]][^&]*>>?[[:space:]]*([^&[:space:]>/]|/(Users|home|private|tmp|var|opt|etc)/)'
}

# The bypass-mode system prompt steers toward heredocs, sed -i, and inline python for file changes.
# In transcripts those errored 4-38% of the time against 0-1.5% for Edit.
if [ -z "${EDIT_GUARD_OFF:-}" ]; then
  if inline_code_writes_file; then
    deny "shell-guard: change a file with the Edit tool (exact old_string -> new_string; it fails loudly on a missed anchor, replace_all for every occurrence). Create a file with the Write tool. Inline scripts that call open(...,'w') or .write() are denied."
  fi
  if uses_in_place_sed; then
    deny "shell-guard: in-place sed is denied (16-38% error rate in your transcripts). Use the Edit tool: old_string -> new_string, replace_all: true for every occurrence."
  fi
  if heredoc_writes_file; then
    deny "shell-guard: create the file with the Write tool (content lands verbatim, no heredoc quoting). Change lines with the Edit tool. A heredoc redirected into a file is denied."
  fi
  if echo_writes_file; then
    deny "shell-guard: append with the Edit tool (old_string = the current last line, new_string = that line plus the addition) or create the file with the Write tool. echo/printf into a file is denied."
  fi
fi

WORK_DIR=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null); [ -z "$WORK_DIR" ] && WORK_DIR=$(pwd -P)
resolve_dir() {
  local base=$1 path=$2
  path=${path#[\"\']}; path=${path%[\"\']}
  case $path in
    '~'|'~/'*) path=$HOME${path#\~} ;;
    '$HOME'|'$HOME/'*) path=$HOME${path#\$HOME} ;;
    *'$'*|*'`'*|-) return ;;
    /*) ;;
    *) [ -n "$base" ] || return; path=$base/$path ;;
  esac
  (cd "$path" 2>/dev/null && pwd -P)
}
in_jj_workspace() {
  local dir=$1
  while [ -n "$dir" ] && [ "$dir" != / ]; do [ -d "$dir/.jj" ] && return 0; [ -e "$dir/.git" ] && return 1; dir=${dir%/*}; done
  return 1
}

while IFS= read -r seg; do
  case "${seg%%[[:space:]]*}" in
    python|python[23]|python[23].[0-9]*|*/python|*/python[23]|*/python[23].[0-9]*|pip|pip3|pip3.[0-9]*|virtualenv|pipenv|poetry)
      [ -z "${UV_GUARD_OFF:-}" ] && deny "shell-guard: Python runs through uv. Script: 'uv run script.py' (deps in '# /// script' metadata). Stdin: uv run - <<'PY'. One-liner: uv run python -c '...'. Extra dep: 'uv run --with PKG ...'. Install: 'uv add PKG' (project) or 'uv pip install PKG'. A .venv project: 'uv run python ...' uses that .venv. A poetry project: convert it with 'uvx migrate-to-uv', then use 'uv run'. Tools: 'uvx ty check', 'ruff check --fix . && ruff format .'." ;;
  esac
  case "$seg" in
    sed|sed[[:space:]]*)
      [ -z "${TOOL_GUARD_OFF:-}" ] && deny "shell-guard: sed is denied. A span: 'bat -pp --line-range A:B FILE'. A span of command output: 'CMD | bat -pp --line-range A:B'. A stream rewrite: 'rg -o PAT -r REPL' or awk. A file change: the Edit tool." ;;
    find|find[[:space:]]*)
      [ -z "${TOOL_GUARD_OFF:-}" ] && deny "shell-guard: find is denied. Use 'fd PATTERN [DIR]' (-e EXT, -t f|d, -H for hidden, -i for -iname, -d N for -maxdepth, -E GLOB for -not -path)." ;;
    awk[[:space:]]-i*)
      [ -z "${TOOL_GUARD_OFF:-}" ] && deny "shell-guard: in-place awk is denied. A file change: the Edit tool; a rule across files: 'sg -p PAT -r REPL --lang X DIR' then -U." ;;
  esac
  [ -n "${JJ_GUARD_OFF:-}" ] && continue
  read -r -a words <<<"$seg"
  case "${words[0]}" in
    cd) WORK_DIR=$(resolve_dir "$WORK_DIR" "${words[1]:-$HOME}") ;;
    z)
      # Mirrors the z function in shell/zoxide.nix.
      case "${#words[@]}:${words[1]:-}" in
        1:) WORK_DIR=$HOME ;;
        2:-) WORK_DIR= ;;
        *) WORK_DIR=$(zoxide query -- "${words[@]:1}" 2>/dev/null) ;;
      esac ;;
    git)
      git_dir=$WORK_DIR; i=1
      while [ "$i" -lt "${#words[@]}" ]; do
        case "${words[$i]}" in
          -C) git_dir=$(resolve_dir "$git_dir" "${words[$((i + 1))]}"); i=$((i + 2)) ;;
          -c|--git-dir|--work-tree|--namespace) i=$((i + 2)) ;;
          -*) i=$((i + 1)) ;;
          *) break ;;
        esac
      done
      case "${words[$i]:-}" in
        add|commit|checkout|switch|stash|reset|restore|rebase|merge|cherry-pick|revert|pull|am|rm|mv)
          in_jj_workspace "$git_dir" && deny "shell-guard: '$git_dir' is a jj workspace, and 'git ${words[$i]}' desyncs jj's working copy. Use jj: add -> nothing (jj tracks every file); commit -> 'jj commit -m MSG'; checkout/switch -> 'jj new REV' or 'jj edit REV'; stash -> 'jj new @-'; reset/restore -> 'jj restore'; rebase -> 'jj rebase'; merge -> 'jj new A B'; pull -> 'jj git fetch'. Read-only git (log, show, diff, blame) stays allowed. The jj skill has the rest." ;;
      esac ;;
  esac
done <<EOF
$(command_segments)
EOF

# The Bash tool runs $SHELL. zsh spells it pipestatus and counts from 1, so ${PIPESTATUS[0]} expands
# to nothing and a failed build reads as an empty status.
if [ -z "${TOOL_GUARD_OFF:-}" ] && [ "${SHELL##*/}" = zsh ] \
   && printf '%s' "$CMD_WITHOUT_HEREDOCS" | sed -E "s/'[^']*'//g" | grep -q 'PIPESTATUS'; then
  deny "shell-guard: the Bash tool runs zsh, where PIPESTATUS is unset. Use \${pipestatus[1]} for the first command's status (zsh counts from 1), or drop the pipe and read \$?."
fi
exit 0
