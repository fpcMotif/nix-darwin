#!/usr/bin/env bash
set -uo pipefail
LOCK=$(realpath "${1:-$(dirname "$0")/doc-lock.sh}")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" XDG_STATE_HOME="$tmp/state"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
unset DOC_LOCK_OFF CLAUDECODE CLAUDE_CODE_SESSION_ID
mkdir -p "$HOME"
repo="$tmp/repo"
fail=0 n=0

report() {
  n=$((n + 1))
  [ "$2" = "$3" ] && return 0
  fail=$((fail + 1))
  printf 'FAIL %s: want=%s got=%s\n%s\n' "$1" "$2" "$3" "$4"
}

edit_case() {
  local out rc got=allow
  out=$(jq -cn --arg s "$3" --arg p "$4" --argjson t "$5" '{session_id: $s, tool_input: ({file_path: $p} + $t)}' |
    (cd "$repo" && "$LOCK" edit) 2>&1)
  rc=$?
  [ "$rc" -eq 2 ] && got=deny
  [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ] && got="error($rc)"
  report "edit $2" "$1" "$got" "$out"
}

grant_case() {
  local got=closed
  jq -cn --arg s "$3" --arg p "$4" '{session_id: $s, prompt: $p}' | "$LOCK" grant >/dev/null
  [ -f "$XDG_STATE_HOME/doc-lock/$3" ] && got=open
  report "grant $2" "$1" "$got" "$4"
}

staged_case() {
  local want=$1 name=$2 out rc got=pass
  shift 2
  out=$(cd "$repo" && env "$@" "$LOCK" staged 2>&1)
  rc=$?
  [ "$rc" -ne 0 ] && got=fail
  report "staged $name" "$want" "$got" "$out"
}

mkdir -p "$repo"
git -C "$repo" init -q
printf 'scratch/\n' >"$repo/.gitignore"
printf '// keep\nconst a = 1;\n// dup\n' >"$repo/a.ts"
printf '{\n  # keep\n  x = 1;\n}\n' >"$repo/flake.nix"
printf '# Notes\n' >"$repo/notes.md"
git -C "$repo" add -A
git -C "$repo" commit -qm init

edit_case deny  "adds a line comment"          s0 "$repo/a.ts" '{"old_string":"const a = 1;","new_string":"// new\nconst a = 1;"}'
edit_case deny  "rewords a comment"            s0 "$repo/a.ts" '{"old_string":"// keep","new_string":"// kept"}'
edit_case deny  "repeats an existing comment"  s0 "$repo/a.ts" '{"old_string":"const a = 1;","new_string":"const a = 1;\n// dup"}'
edit_case deny  "adds a suppression"           s0 "$repo/a.ts" '{"old_string":"const a = 1;","new_string":"// @ts-expect-error\nconst a = 1;"}'
edit_case allow "changes code only"            s0 "$repo/a.ts" '{"old_string":"const a = 1;","new_string":"const a = 2;"}'
edit_case allow "deletes a comment"            s0 "$repo/a.ts" '{"old_string":"// keep\n","new_string":""}'
edit_case allow "reindents a comment"          s0 "$repo/a.ts" '{"old_string":"// keep","new_string":"    // keep"}'
edit_case allow "comment markers in strings"   s0 "$repo/b.ts" '{"content":"const s = \"// no\";\nconst r = /\\/\\//;\nconst t = `/* no */`;\n"}'
edit_case allow "shebang on a new script"      s0 "$repo/c.sh" '{"content":"#!/usr/bin/env bash\necho \"# no\"\n"}'
edit_case deny  "comment in a new script"      s0 "$repo/c.py" '{"content":"#!/usr/bin/env python3\n# note\nx = 1\n"}'
edit_case deny  "adds a Nix comment"           s0 "$repo/flake.nix" '{"old_string":"x = 1;","new_string":"# why\n  x = 1;"}'
edit_case allow "moves a Nix comment"          s0 "$repo/flake.nix" '{"content":"{\n  x = 1;\n  # keep\n}\n"}'
edit_case deny  "MultiEdit adds a comment"     s0 "$repo/a.ts" '{"edits":[{"old_string":"const a = 1;","new_string":"const a = 3;"},{"old_string":"const a = 3;","new_string":"/* new */ const a = 3;"}]}'
edit_case allow "replace_all on code"          s0 "$repo/a.ts" '{"old_string":"a","new_string":"b","replace_all":true}'
edit_case deny  "relative path"                s0 "a.ts" '{"old_string":"const a = 1;","new_string":"// new\nconst a = 1;"}'
edit_case deny  "edits Markdown"               s0 "$repo/notes.md" '{"old_string":"# Notes","new_string":"# More notes"}'
edit_case deny  "creates an ADR"               s0 "$repo/docs/adr/0001-x.md" '{"content":"# x\n"}'
edit_case allow "Markdown in an ignored path"  s0 "$repo/scratch/plan.md" '{"content":"# plan\n"}'
edit_case allow "Markdown outside a repo"      s0 "$tmp/outside.md" '{"content":"# plan\n"}'
edit_case allow "language without a parser"    s0 "$repo/a.toml" '{"content":"# c\nx = 1\n"}'
DOC_LOCK_OFF=1 edit_case allow "DOC_LOCK_OFF"  s0 "$repo/notes.md" '{"content":"# x\n"}'

grant_case closed "plain task"                s1 "fix the failing test in auth.ts"
grant_case open   "ADR request"               s2 "please update the ADR for the cache"
grant_case open   "CONTEXT request"           s3 "Update CONTEXT with the new term"
grant_case closed "lowercase context"         s4 "shrink the context window"
grant_case open   "domain-modeling skill"     s5 "/mattpocock-skills:domain-modeling sharpen terms"
grant_case open   "comment request"           s6 "fix the stale comments in parser.rs"
grant_case open   "matt skills setup"         s7 "run setup-matt-pocock-skills here"
grant_case open   "slash command wrapper"     s8 $'<command-message>x</command-message>\n<command-name>/mattpocock-skills:domain-modeling</command-name>\n<command-args>terms</command-args>'
grant_case closed "task notification"         s9 $'<task-notification>\n<result>doc-lock: update the ADR</result>\n</task-notification>'
grant_case closed "teammate message"          s10 '<teammate-message from="lead">update the docs</teammate-message>'
grant_case closed "pasted block"              s11 $'<pasted_content id="1">fix the comments</pasted_content>\nnow fix the bug'

edit_case allow "granted Markdown"             s2 "$repo/notes.md" '{"content":"# x\n"}'
edit_case allow "granted comment"              s2 "$repo/a.ts" '{"old_string":"const a = 1;","new_string":"// new\nconst a = 1;"}'
edit_case deny  "grant stays per session"      s1 "$repo/notes.md" '{"content":"# x\n"}'

printf '// keep\nconst a = 1;\n// dup\n// added\n' >"$repo/a.ts"
git -C "$repo" add a.ts
staged_case pass "human commit"               CLAUDECODE=
staged_case fail "agent adds a comment"       CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=s1
staged_case pass "agent with a grant"         CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=s2
git -C "$repo" reset -q --hard

printf 'const a = 1;\n// dup\n' >"$repo/a.ts"
printf '#!/usr/bin/env bash\necho hi\n' >"$repo/run.sh"
git -C "$repo" add a.ts run.sh
staged_case pass "agent deletes a comment"    CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=s1
git -C "$repo" reset -q --hard
rm -f "$repo/run.sh"

printf '# Notes\nmore\n' >"$repo/notes.md"
git -C "$repo" add notes.md
staged_case fail "agent edits Markdown"       CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=s1
git -C "$repo" reset -q --hard

git -C "$repo" rm -q notes.md
staged_case fail "agent deletes Markdown"     CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=s1
git -C "$repo" reset -q --hard

strip_case() {
  local out got
  printf '%s' "$3" >"$repo/$2"
  out=$(cd "$repo" && "$LOCK" strip "$2" 2>&1)
  got=$(cat "$repo/$2"; printf .)
  report "strip $1" "$4." "$got" "$out"
}

strip_case "TypeScript against HEAD" a.ts \
  $'// keep\n// new\nconst a = 1; // trailing\n/* lead */ const b = 2;\n// dup\n// dup\nconst s = "// no";' \
  $'// keep\nconst a = 1;\nconst b = 2;\n// dup\nconst s = "// no";'
strip_case "Nix against HEAD" flake.nix \
  $'{\n  # keep\n  # why\n  x = 1; /* inline */\n}\n' \
  $'{\n  # keep\n  x = 1;\n}\n'
strip_case "new Python file, non-ASCII" new.py \
  $'#!/usr/bin/env python3\n# note \xe2\x80\x94 \xc3\xa9\nx = "\xc3\xa9"  # tail\n' \
  $'#!/usr/bin/env python3\nx = "\xc3\xa9"\n'
strip_case "Rust doc comment" lib.rs \
  $'fn a() {}\n    /// doc\n    fn f() {}\n' \
  $'fn a() {}\n    fn f() {}\n'
strip_case "language without a parser" a.toml $'# c\nx = 1\n' $'# c\nx = 1\n'
strip_case "already clean" flake.nix $'{\n  # keep\n  x = 1;\n}\n' $'{\n  # keep\n  x = 1;\n}\n'

printf '// keep\n// abs\nconst a = 1;\n// dup\n' >"$repo/a.ts"
"$LOCK" strip "$repo/a.ts" >/dev/null
report "strip absolute path" $'// keep\nconst a = 1;\n// dup\n.' "$(cat "$repo/a.ts"; printf .)" ""

echo "doc-lock: $((n - fail))/$n passed"
[ "$fail" -eq 0 ]
