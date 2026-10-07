#!/usr/bin/env bash
set -uo pipefail
LOCK=$(realpath "${1:-$(dirname "$0")/doc-lock.sh}")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" XDG_STATE_HOME="$tmp/state"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
unset DOC_LOCK_OFF CLAUDECODE CLAUDE_CODE_SESSION_ID CODEX_SESSION_ID PI_CODING_AGENT PI_SESSION_ID AGENT DOC_LOCK_SESSION
mkdir -p "$HOME"
repo="$tmp/repo"
fail=0 n=0

report() {
  n=$((n + 1))
  [ "$2" = "$3" ] && return 0
  fail=$((fail + 1))
  printf 'FAIL %s: want=%s got=%s\n%s\n' "$1" "$2" "$3" "$4"
}

run_edit() {
  local out rc got=allow
  out=$(printf '%s' "$3" | (cd "$repo" && "$LOCK" edit) 2>&1)
  rc=$?
  [ "$rc" -eq 2 ] && got=deny
  [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ] && got="error($rc)"
  report "$2" "$1" "$got" "$out"
}

edit_case() {
  run_edit "$1" "edit $2" "$(jq -cn --arg s "$3" --arg p "$4" --argjson t "$5" '{session_id: $s, tool_input: ({file_path: $p} + $t)}')"
}

patch_case() {
  run_edit "$1" "patch $2" "$(jq -cn --arg s "$3" --arg cwd "$repo" --arg c "$4" '{session_id: $s, cwd: $cwd, tool_name: "apply_patch", tool_input: {command: $c}}')"
}

tool_case() {
  run_edit "$1" "tool $2" "$(jq -cn --arg cwd "$repo" --argjson t "$3" '{session_id: "s0", cwd: $cwd, tool_input: $t}')"
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

patch_case deny  "adds a comment"        s0 $'*** Begin Patch\n*** Update File: a.ts\n@@\n-const a = 1;\n+// new\n+const a = 1;\n*** End Patch'
patch_case deny  "rewords a comment"     s0 $'*** Begin Patch\n*** Update File: a.ts\n@@\n-// keep\n+// kept\n*** End Patch'
patch_case allow "moves a comment"       s0 $'*** Begin Patch\n*** Update File: a.ts\n@@\n-// keep\n const a = 1;\n+// keep\n*** End Patch'
patch_case allow "changes code only"     s0 $'*** Begin Patch\n*** Update File: a.ts\n@@\n-const a = 1;\n+const a = 2;\n*** End Patch'
patch_case allow "deletes a comment"     s0 $'*** Begin Patch\n*** Update File: a.ts\n@@\n-// keep\n const a = 1;\n*** End Patch'
patch_case deny  "new file with comment" s0 $'*** Begin Patch\n*** Add File: new.py\n+# note\n+x = 1\n*** End Patch'
patch_case allow "new script, shebang"   s0 $'*** Begin Patch\n*** Add File: run.sh\n+#!/usr/bin/env bash\n+echo "# no"\n*** End Patch'
patch_case deny  "second file comments"  s0 $'*** Begin Patch\n*** Update File: a.ts\n@@\n-const a = 1;\n+const a = 2;\n*** Update File: flake.nix\n@@\n-  x = 1;\n+  # why\n+  x = 1;\n*** End Patch'
patch_case deny  "adds Markdown"         s0 $'*** Begin Patch\n*** Add File: docs/adr/0002-x.md\n+# x\n*** End Patch'
patch_case deny  "deletes Markdown"      s0 $'*** Begin Patch\n*** Delete File: notes.md\n*** End Patch'
patch_case deny  "renames into Markdown" s0 $'*** Begin Patch\n*** Update File: a.ts\n*** Move to: a.md\n*** End Patch'
patch_case allow "ignored Markdown"      s0 $'*** Begin Patch\n*** Add File: scratch/plan.md\n+# plan\n*** End Patch'

tool_case deny  "pi edit adds a comment"        '{"path":"a.ts","edits":[{"oldText":"const a = 1;","newText":"// new\nconst a = 1;"}]}'
tool_case allow "pi edit changes code"          '{"path":"a.ts","edits":[{"oldText":"const a = 1;","newText":"const a = 2;"}]}'
tool_case deny  "pi write Markdown"             '{"path":"notes.md","content":"# x\n"}'
tool_case deny  "omp replace adds a comment"    '{"path":"flake.nix","old_string":"x = 1;","new_string":"# why\n  x = 1;"}'
tool_case deny  "omp apply_patch comment"       '{"input":"*** Begin Patch\n*** Update File: a.ts\n@@\n-const a = 1;\n+const a = 1; // tail\n*** End Patch"}'
tool_case deny  "omp patch mode comment"        '{"path":"a.ts","edits":[{"op":"update","diff":"@@\n-const a = 1;\n+/* new */ const a = 1;"}]}'
tool_case allow "omp patch mode code"           '{"path":"a.ts","edits":[{"op":"update","diff":"@@\n-const a = 1;\n+const a = 3;"}]}'
tool_case deny  "omp patch renames to Markdown" '{"path":"a.ts","edits":[{"rename":"a.md"}]}'
tool_case deny  "hashline adds a comment"       '{"input":"[a.ts#1a2b]\nPUT <2:\n+// new","path":"a.ts","paths":["a.ts"]}'
tool_case deny  "hashline in an envelope"       '{"input":"*** Begin Patch\n[a.ts#1a2b]\nPUT <2:\n+// new\n*** End Patch"}'
tool_case allow "hashline re-puts a comment"    '{"input":"[a.ts#1a2b]\nPUT 1.=2:\n+// keep\n+const a = 9;","path":"a.ts"}'
tool_case allow "hashline changes code"         '{"input":"[a.ts#5494]\nPUT 1.=1:\n+const a = 2;","path":"a.ts","paths":["a.ts"]}'
tool_case deny  "hashline edits Markdown"       '{"input":"[notes.md#00ff]\nPUT >$:\n+more","path":"notes.md"}'
tool_case deny  "hashline removes Markdown"     '{"input":"[notes.md#00ff]\nREM","path":"notes.md"}'
tool_case deny  "hashline moves into Markdown"  '{"input":"[a.ts#1a2b]\nMV a.md","path":"a.ts"}'

edit_case allow "first edit records a baseline" s20 "$repo/a.ts" '{"old_string":"// keep\n","new_string":""}'
printf 'const a = 1;\n// dup\n' >"$repo/a.ts"
edit_case allow "restores a comment it removed" s20 "$repo/a.ts" '{"old_string":"const a = 1;","new_string":"// keep\nconst a = 1;"}'
edit_case deny  "restores it twice"             s20 "$repo/a.ts" '{"old_string":"const a = 1;","new_string":"// keep\n// keep\nconst a = 1;"}'
edit_case deny  "restore plus a new comment"    s20 "$repo/a.ts" '{"old_string":"const a = 1;","new_string":"// keep\n// new\nconst a = 1;"}'
edit_case deny  "another session adds it"       s21 "$repo/a.ts" '{"old_string":"const a = 1;","new_string":"// keep\nconst a = 1;"}'
patch_case allow "restores a removed comment"   s20 $'*** Begin Patch\n*** Update File: a.ts\n@@\n-const a = 1;\n+// keep\n+const a = 1;\n*** End Patch'
patch_case deny  "repeats a comment on disk"    s20 $'*** Begin Patch\n*** Update File: a.ts\n@@\n-const a = 1;\n+// dup\n+const a = 1;\n*** End Patch'
snapshot="$XDG_STATE_HOME/doc-lock/baseline/s20/$(printf '%s' "$repo/a.ts" | sha256sum | cut -c1-64)"
printf '// forged\n' >>"$snapshot"
edit_case deny  "a changed baseline is ignored" s20 "$repo/a.ts" '{"old_string":"const a = 1;","new_string":"// keep\nconst a = 1;"}'
git -C "$repo" checkout -q -- a.ts

edit_case allow "test environment pragma"       s0 "$repo/a.test.ts" '{"content":"// @vitest-environment node\nimport { test } from \"vitest\";\n"}'
edit_case allow "triple-slash reference"        s0 "$repo/env.d.ts" '{"content":"/// <reference types=\"vite/client\" />\nexport {};\n"}'
edit_case allow "JSX pragma"                    s0 "$repo/p.tsx" '{"content":"/** @jsxImportSource preact */\nexport const x = <div />;\n"}'
edit_case allow "Go build constraint"           s0 "$repo/x.go" '{"content":"//go:build linux\n\npackage x\n"}'
edit_case allow "uv script metadata"            s0 "$repo/tool.py" '{"content":"# /// script\n# requires-python = \">=3.12\"\n# dependencies = []\n# ///\nprint(1)\n"}'
edit_case allow "encoding cookie"               s0 "$repo/enc.py" '{"content":"# -*- coding: utf-8 -*-\nx = 1\n"}'
edit_case deny  "prose after a pragma"          s0 "$repo/b.test.ts" '{"content":"// @vitest-environment node because jsdom is slow\n"}'
edit_case deny  "comment after a script block"  s0 "$repo/tool2.py" '{"content":"# /// script\n# dependencies = []\n# ///\n# note\nprint(1)\n"}'
edit_case deny  "eslint suppression"            s0 "$repo/a.ts" '{"old_string":"const a = 1;","new_string":"// eslint-disable-next-line\nconst a = 1;"}'
edit_case deny  "noqa suppression"              s0 "$repo/n.py" '{"content":"import os  # noqa: F401\n"}'

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
staged_case fail "Codex adds a comment"       CLAUDECODE= CODEX_SESSION_ID=c1
staged_case pass "Codex with a grant"         CLAUDECODE= CODEX_SESSION_ID=s2
staged_case fail "pi adds a comment"          CLAUDECODE= PI_CODING_AGENT=true PI_SESSION_ID=p1
staged_case fail "omp adds a comment"         CLAUDECODE= AGENT=1
staged_case pass "omp with a grant"           CLAUDECODE= AGENT=1 DOC_LOCK_SESSION=s2
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
strip_case "keeps a directive" t.test.ts \
  $'// @vitest-environment node\n// note\nconst a = 1;\n' \
  $'// @vitest-environment node\nconst a = 1;\n'
strip_case "already clean" flake.nix $'{\n  # keep\n  x = 1;\n}\n' $'{\n  # keep\n  x = 1;\n}\n'

printf '// keep\n// abs\nconst a = 1;\n// dup\n' >"$repo/a.ts"
"$LOCK" strip "$repo/a.ts" >/dev/null
report "strip absolute path" $'// keep\nconst a = 1;\n// dup\n.' "$(cat "$repo/a.ts"; printf .)" ""

echo "doc-lock: $((n - fail))/$n passed"
[ "$fail" -eq 0 ]
