#!/usr/bin/env bash
set -euo pipefail
[ -n "${DOC_LOCK_OFF:-}" ] && exit 0

grants="${XDG_STATE_HOME:-$HOME/.local/state}/doc-lock"
docs_words='adrs?|context\.md|docs?|documentation|document(ed)?|readme|comments?|changelog|agents\.md|claude\.md|skill\.md|setup-matt-pocock-skills|domain-modeling|writing-for-agents'
unlock_hint='If the user wants it, ask them to request docs work (for example "update the ADR" or "fix the comments"); that opens the lock for the session.'

is_open() { [ -n "$1" ] && [ -f "$grants/$1" ]; }

is_markdown() { case "$1" in *.md | *.mdx | *.markdown) return 0 ;; *) return 1 ;; esac; }

absolute() { case "$1" in /*) echo "$1" ;; *) echo "$PWD/$1" ;; esac; }

on_disk() { if [ -f "$1" ]; then echo "$1"; else echo /dev/null; fi; }

language() {
  case "${1##*.}" in
    ts | mts | cts) echo typescript ;;
    tsx) echo tsx ;;
    js | jsx | mjs | cjs) echo javascript ;;
    py | pyi) echo python ;;
    rs) echo rust ;;
    go) echo go ;;
    nix) echo nix ;;
    sh | bash | zsh) echo bash ;;
    swift) echo swift ;;
    kt | kts) echo kotlin ;;
    java) echo java ;;
    c | h) echo c ;;
    cc | cpp | cxx | hh | hpp) echo cpp ;;
    cs) echo csharp ;;
    rb) echo ruby ;;
    lua) echo lua ;;
    ex | exs) echo elixir ;;
    hs) echo haskell ;;
    php) echo php ;;
    scala) echo scala ;;
    yml | yaml) echo yaml ;;
    css) echo css ;;
    html | htm) echo html ;;
    tf | hcl) echo hcl ;;
    *) return 1 ;;
  esac
}

jq_lib='
def code_comments: .[] | select(.range.byteOffset.start > 0 or (.text | startswith("#!") | not));
def norm: gsub("\\s+"; " ") | ltrimstr(" ") | rtrimstr(" ");
def new_comments:
  (reduce ($kept | split("\n")[] | select(. != "")) as $t ({}; .[$t] += 1)) as $counts
  | reduce code_comments as $c ({counts: $counts, new: []};
      ($c.text | norm) as $t
      | if (.counts[$t] // 0) > 0 then .counts[$t] -= 1 else .new += [$c] end)
  | .new;
def report($lines):
  (.[:5][] | "  \(if $lines then "line \(.range.start.line + 1): " else "" end)\(.text | norm | .[:160])"),
  (select(length > 5) | "  and \(length - 5) more");
'

scan() {
  local -a kinds
  case $1 in
    rust | java) kinds=(line_comment block_comment) ;;
    kotlin) kinds=(line_comment multiline_comment) ;;
    swift) kinds=(comment multiline_comment) ;;
    scala) kinds=(comment block_comment) ;;
    *) kinds=(comment) ;;
  esac
  ast-grep scan --stdin --json=compact --inline-rules "id: comment
language: $1
rule: { any: [$(printf '{kind: %s},' "${kinds[@]}")] }"
}

comments() { scan "$1" | jq -r "$jq_lib code_comments | .text | norm"; }

added_comments() {
  scan "$1" <"$3" | jq -r --rawfile kept <(comments "$1" <"$2") "$jq_lib new_comments | report(${4:-true})"
}

in_work_tree() {
  local dir rc=0
  dir=$(dirname "$1")
  while [ ! -d "$dir" ]; do dir=$(dirname "$dir"); done
  git -C "$dir" check-ignore -q -- "$1" 2>/dev/null || rc=$?
  [ "$rc" = 1 ]
}

grant() {
  local session
  session=$(jq -r --arg words "$docs_words" '
    (.prompt // "" | gsub("</?command-(name|args|message)>"; " ")
      | gsub("<(?<tag>[A-Za-z][\\w-]*)[^>]*>[\\s\\S]*?</\\k<tag>>"; "")) as $typed
    | select($typed | test("\\b(" + $words + ")\\b"; "i") or test("\\bCONTEXT\\b"))
    | .session_id // empty')
  [ -n "$session" ] || return 0
  mkdir -p "$grants"
  find "$grants" -type f -mtime +7 -delete
  : >"$grants/$session"
  echo "doc-lock: open for this session, so comment and Markdown changes are allowed."
}

proposed='
def swap($e): ($e.old_string // $e.oldText // "") as $o | ($e.new_string // $e.newText // "") as $n
  | if $o == "" then $n
    elif $e.replace_all == true then split($o) | join($n)
    else split($o) as $p | if ($p | length) < 2 then . else $p[0] + $n + ($p[1:] | join($o)) end
    end;
.tool_input as $t
| if $t.content != null then $t.content
  else reduce ($t.edits // [$t])[] as $e ($before; swap($e))
  end'

keep_hint="Keep existing comments as written and carry intent in names, types, and tests. Deleting a comment together with its code is fine. Put what a Markdown doc should say in your reply. $unlock_hint"

refuse_markdown() { echo "doc-lock: $1 is Markdown, which stays unchanged outside docs work." >&2; }

refuse_comments() { printf 'doc-lock: %s gains new or reworded comments:\n%s\n' "$1" "$2" >&2; }

block() {
  echo "$keep_hint" >&2
  exit 2
}

file_edit() {
  local input=$1 path=$2 old lang added
  [ -n "$path" ] || return 0
  path=$(absolute "$path")
  in_work_tree "$path" || return 0
  if is_markdown "$path"; then
    refuse_markdown "$path"
    block
  fi
  lang=$(language "$path") || return 0
  old=$(on_disk "$path")
  added=$(added_comments "$lang" "$old" <(jq -r --rawfile before "$old" "$proposed" <<<"$input"))
  [ -z "$added" ] && return 0
  refuse_comments "$path" "$added"
  block
}

envelope_files='
def body($l):
  if ($l | startswith("+")) then .added += $l[1:] + "\n"
  elif ($l | startswith("-")) then .removed += $l[1:] + "\n"
  elif ($l | startswith("*** Move to: ")) then .move = ($l | ltrimstr("*** Move to: "))
  elif ($l | startswith("MV ")) then .move = ($l | ltrimstr("MV "))
  elif ($l | rtrimstr(" ")) == "REM" then .op = "Delete"
  else .
  end;
def header($l):
  if ($l | test("^\\*\\*\\* (Add|Update|Delete) File: ")) then
    {op: ($l | capture("^\\*\\*\\* (?<op>\\w+)").op), path: ($l | sub("^\\*\\*\\* \\w+ File: "; "")), base: "lines"}
  elif ($l | test("^\\[.+#[0-9A-Fa-f]{4}\\]\\s*$")) then
    {op: "Update", path: ($l | capture("^\\[(?<p>.+)#[0-9A-Fa-f]{4}\\]").p), base: "file"}
  else empty
  end;
.tool_input as $t
| if ($t.edits | type) == "array" and ($t.edits | any(has("diff") or has("op") or has("rename"))) then
    $t.edits[] | . as $e
    | reduce ((.diff // "") | split("\n"))[] as $l
        ({op: ({create: "Add", delete: "Delete"}[$e.op // ""] // "Update"), path: $t.path, base: "lines",
          added: "", removed: ""} + (if $e.rename then {move: $e.rename} else {} end);
         body($l))
  else
    ((($t.command // $t.input) | strings) // "") | split("\n")
    | reduce .[] as $l ({files: [], cur: null};
        [header($l)] as $h
        | if $h != [] then .files += [$h[0] + {added: "", removed: ""}] | .cur = (.files | length) - 1
          elif .cur == null then .
          else .files[.cur] |= body($l)
          end)
    | .files[]
  end'

envelope_edit() {
  local entries=$1 entry op base path target lang added found=0
  while IFS= read -r entry; do
    IFS=$'\t' read -r op base path target < <(jq -r '[.op, .base, .path, .move // .path] | @tsv' <<<"$entry")
    path=$(absolute "$path")
    target=$(absolute "$target")
    in_work_tree "$path" || in_work_tree "$target" || continue
    if is_markdown "$path" || is_markdown "$target"; then
      refuse_markdown "$target"
      found=1
      continue
    fi
    [ "$op" = Delete ] && continue
    lang=$(language "$target") || continue
    if [ "$base" = file ]; then
      added=$(added_comments "$lang" "$(on_disk "$path")" <(jq -r '.added' <<<"$entry") false)
    else
      added=$(added_comments "$lang" <(jq -r '.removed' <<<"$entry") <(jq -r '.added' <<<"$entry") false)
    fi
    if [ -n "$added" ]; then
      refuse_comments "$target" "$added"
      found=1
    fi
  done <<<"$entries"
  [ "$found" = 0 ] || block
}

edit() {
  local input session cwd path entries
  input=$(cat)
  {
    IFS= read -r session
    IFS= read -r cwd
    IFS= read -r path
  } < <(jq -r '.session_id // "", .cwd // "", .tool_input.file_path // .tool_input.path // ""' <<<"$input")
  is_open "$session" && return 0
  [ -z "$cwd" ] || cd "$cwd"
  entries=$(jq -c "$envelope_files" <<<"$input")
  if [ -n "$entries" ]; then
    envelope_edit "$entries"
  else
    file_edit "$input" "$path"
  fi
}

agent_session() {
  if [ "${CLAUDECODE:-}" = 1 ]; then echo "${CLAUDE_CODE_SESSION_ID:-}"
  elif [ -n "${CODEX_SESSION_ID:-}" ]; then echo "$CODEX_SESSION_ID"
  elif [ "${PI_CODING_AGENT:-}" = true ]; then echo "${PI_SESSION_ID:-}"
  elif [ "${AGENT:-}" = 1 ]; then echo "${DOC_LOCK_SESSION:-}"
  else return 1
  fi
}

staged() {
  local session status path lang added found=0
  session=$(agent_session) || return 0
  is_open "$session" && return 0
  while IFS= read -r -d '' status && IFS= read -r -d '' path; do
    if is_markdown "$path"; then
      refuse_markdown "$path"
      found=1
    elif [ "$status" != D ] && lang=$(language "$path"); then
      added=$(added_comments "$lang" <(git show "HEAD:$path" 2>/dev/null || true) <(git show ":$path"))
      if [ -n "$added" ]; then
        refuse_comments "$path" "$added"
        found=1
      fi
    fi
  done < <(git diff --cached --name-status --no-renames -z)
  [ "$found" = 0 ] && return 0
  echo "Undo these doc changes: \`doc-lock strip FILE...\` deletes the comments each file gained since HEAD. Comments and Markdown change only in docs work. If the user made a change, keep it and ask them to commit it. $unlock_hint" >&2
  return 1
}

strip_ranges='
new_comments | sort_by(-.range.byteOffset.start)[]
| [.range.byteOffset.start, .range.byteOffset.end - (if (.text | endswith("\n")) then 1 else 0 end)]
| @tsv'

splice='
($src | explode) as $source
| ([$source[] | if . < 128 then 1 elif . < 2048 then 2 elif . < 65536 then 3 else 4 end]
   | reduce .[] as $width ([0]; . + [.[-1] + $width])) as $offsets
| reduce ($ranges | split("\n")[] | split("\t") | map(tonumber)) as [$from, $to] ($source;
    . as $s | ($s | length) as $n
    | ($offsets | bsearch($from)) as $c
    | ($offsets | bsearch($to)) as $b
    | ($c | until(. == 0 or ($s[. - 1] | . == 32 or . == 9 | not); . - 1)) as $a
    | ($b | until(. == $n or ($s[.] | . == 32 or . == 9 or . == 13 | not); . + 1)) as $e
    | ($a == 0 or $s[$a - 1] == 10) as $alone_before
    | if $alone_before and ($e == $n or $s[$e] == 10) then $s[:$a] + $s[([$e + 1, $n] | min):]
      elif $alone_before then $s[:$c] + $s[$e:]
      else $s[:$a] + $s[$b:]
      end)
| implode'

strip() {
  local path lang kept ranges tmp
  for path in "$@"; do
    lang=$(language "$path") || continue
    kept=$(git -C "$(dirname "$path")" show "HEAD:./$(basename "$path")" 2>/dev/null | comments "$lang" || true)
    ranges=$(scan "$lang" <"$path" | jq -r --rawfile kept <(printf '%s' "$kept") "$jq_lib $strip_ranges")
    [ -n "$ranges" ] || continue
    tmp=$(mktemp)
    jq -nj --rawfile src "$path" --arg ranges "$ranges" "$splice" >"$tmp"
    cat "$tmp" >"$path"
    rm -f "$tmp"
    echo "doc-lock: stripped $(wc -l <<<"$ranges" | tr -d ' ') comment(s) from $path"
  done
}

case "${1:-}" in
  grant) grant ;;
  edit) edit ;;
  staged) staged ;;
  strip)
    shift
    strip "$@"
    ;;
  *)
    echo "usage: doc-lock grant|edit|staged|strip FILE..." >&2
    exit 64
    ;;
esac
