#!/bin/bash
# The nix check runs the hook from the store, so it passes that path in.
HOOK=${1:-$(dirname "$0")/shell-guard.sh}
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
PLAIN=$TMP/plain; JJ=$TMP/jj; mkdir -p "$PLAIN" "$JJ/.jj" "$JJ/sub"
COLOCATED=$TMP/colo; WORKTREE=$COLOCATED/.claude/worktrees/wt; JJ_WORKSPACE=$TMP/jj-ws
mkdir -p "$COLOCATED/.jj" "$COLOCATED/.git" "$COLOCATED/sub" "$WORKTREE/sub" "$JJ_WORKSPACE/.jj"; touch "$WORKTREE/.git" "$JJ_WORKSPACE/.git"
fail=0; n=0
check() {
  want=$1; cmd=$2; cwd=${3:-$PLAIN}; n=$((n + 1))
  out=$(jq -cn --arg c "$cmd" --arg d "$cwd" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' | bash "$HOOK" 2>&1 >/dev/null); rc=$?
  got=allow; [ "$rc" -eq 2 ] && got=deny
  if [ "$got" != "$want" ]; then fail=$((fail + 1)); printf 'FAIL want=%s got=%s rc=%s: %s\n  %s\n' "$want" "$got" "$rc" "$cmd" "$out"; fi
}

check deny  "python3 script.py"
check deny  "python -c 'print(1)'"
check deny  $'python3 - "$k" <<\'PY\'\nimport json\nprint(1)\nPY'
check deny  "cd /x && python3 fingerprint.py seed.txt > fp.json"
check deny  "pip install httpx"
check deny  "pip3 install -r requirements.txt"
check deny  "python3 -m venv .venv"
check deny  "./.venv/bin/python3 app.py"
check deny  "FOO=1 python3 app.py"
check deny  "sudo python3 app.py"
check deny  "x=\$(python3 -c 'print(2)')"
check allow "uv run script.py"
check allow "uv run python -c 'print(1)'"
check allow "uv run --with httpx python -c 'import httpx'"
check allow $'uv run - <<\'PY\'\nprint(1)\nPY'
check allow "uvx ty check"
check allow "uv add httpx; uv sync; uv run pytest"
check allow "command -v python3"
check allow "which python3 python"
check allow "rg -n python3 modules/"
check allow "bat -pp docs/python-notes.md"
check allow "ls python3-helpers/"
check allow $'uv run - <<\'PY\'\n# run with python3 foo.py\nprint(1)\nPY'

check deny  $'python3 - <<\'EOF\'\np="a.tsx"\ns=open(p).read()\ns=s.replace("a","b")\nopen(p,"w").write(s)\nEOF'
check deny  $'uv run - <<\'PY\'\nfrom pathlib import Path\nPath("a.txt").write_text("x")\nPY'
check deny  "uv run python -c \"open('a','w').write('x')\""
check deny  "node -e \"require('fs').writeFileSync('a','x')\""
check deny  "sed -i '' 's/a/b/' file.ts"
check deny  "sed -i.bak -e 's/a/b/' file.ts"
check deny  "cat file | sed -i 's/a/b/' other"
check deny  $'cat > out.md <<\'EOF\'\nhello\nEOF'
check deny  $'cat <<\'EOF\' > out.md\nhello\nEOF'
check deny  $'cat <<EOF >> notes.md\nline\nEOF'
check deny  $'tee /etc/foo.conf <<EOF\nx\nEOF'
check deny  $'tee -a ~/.zshrc <<EOF\nx\nEOF'
check deny  "echo 'x' >> .gitignore"
check deny  "printf '%s\\n' abc > seed-t.txt"
check deny  "cd /tmp && echo hi > note.txt"
check deny  "echo '{}' > /Users/me/proj/config.json"
check deny  "sed -n '1,20p' file.ts"
check deny  "rg -l PAT src | sed -E 's/a/b/'"
check allow "cat file.ts"
check allow "cat -n file.ts | head -n 40"
check allow "x=\$(cat VERSION)"
check deny  "find . -name '*.ts' -not -path '*/node_modules/*'"
check deny  "awk -i inplace '{sub(/a/,\"b\")}1' file.ts"
check allow "awk -F: '{print \$1}' /etc/passwd | head -n 3"
check allow "uv run gen.py > out.json"
check allow "uv run fingerprint.py seed-t.txt > fp-t.json"
check allow "bat -pp --line-range 1:40 file.ts"
check allow "bat -pp VERSION"
check allow "jq '.version' package.json"
check allow "rg -o 'v[0-9]+' -r 'ver' file.ts"
check allow "fd -e ts . src | head -n 20"
check allow "concat-files a b"
check allow $'cat <<\'EOF\' | jq .\n{}\nEOF'
check allow $'gh pr create --body "$(cat <<\'EOF\'\nbody\nEOF\n)"'
check allow $'git commit -F - <<\'EOF\'\nfeat: x\nEOF'
check allow "echo hi"
check allow "echo hi >&2"
check allow "echo hi > /dev/null"
check allow $'cat > /dev/null <<EOF\nx\nEOF'
check allow "printf '%s\\n' a b | sort"
check allow "rg -n 'open\\(' src/ | head"
check allow "bun run build > build.log 2>&1"
check allow "jq '.a' in.json > out.json"
check allow "git diff > /tmp/x.diff"
check allow "bat -pp --line-range 1:30 hooks/shell-guard.sh"

# Separators inside quotes do not start a command. A $( inside double quotes does.
check allow "rg -n \"ls|find|fff\" x"
check allow "rg -n 'a|sed' x"
check allow "rg -n \$'a|find' x"
check allow "git commit -m \"fix; find . works\""
check allow $'rg -n "a\nfind b" x'
check allow $'ls # don\'t run find here'
check allow "ls | grep foo"
check deny  "echo x | sed s/a/b/"
check deny  "find . -name x"
check deny  "rg -n 'a|b' x; find . -name y"
check allow "echo \"v=\$(cat VERSION)\""
check deny  $'ls # don\'t\nfind .'
check allow 'echo "$p -> $(readlink -f "$p")"'
check allow 'for p in a b; do echo "$p -> $(readlink -f "$p")"; done'
check allow "printf '%s -> ' x"
check allow "echo 'a >> b' | tr a b"
check allow 'echo 1 \> 2'
check allow "echo x 2>&1"
check allow "echo x >/dev/null"
check deny  "echo x > file"
check deny  "echo x >> /tmp/f"
check deny  'echo "a -> b" > out.txt'
check deny  'printf "%s\n" x > "$out"'

check allow "rg -o -r '<<HIT>>' 'needle' src/a.ts"
check allow "rg -n '^(<<<<<<<|>>>>>>>)' src/"
check allow "bun -e 'const x = b[p] << 24; console.log(x)'"
check allow $'git commit -F - > /tmp/commit.log <<\'EOF\'\nfix: x\nEOF'
check deny  $'cat > /dev/null <<\'EOF\'\nEOF\ncat > out.md <<\'EOF\'\nhello\nEOF'
check deny  "cat <<< 'text' > out.md"
check allow "bat -pp /x/lib/python3.14/site-packages/pkg/mod.py"
check allow "rg -n foo .venv/lib/python3.12/site-packages/"
check deny  "python3.12 -m pytest"
check deny  "/usr/bin/python3 x.py"
check deny  "poetry run pytest"
check allow $'uv run - <<\'PY\'\nimport json\nprint(json.load(open("audit/report.json")))\nPY'
check allow $'uv run - <<\'PY\'\nfrom PIL import Image\nprint(Image.open("assets/logo.png").size)\nPY'
check deny  $'uv run - <<\'PY\'\nwith open("out.txt", mode="a") as f:\n    f.write("x")\nPY'
check deny  "git show HEAD:a.ts | sed -n 150,234p"

# Git writes in a jj workspace go to jj. Read-only git and plain Git checkouts pass.
check deny  "git add -N a.md" "$JJ"
check deny  "git commit -m 'x'" "$JJ"
check deny  "git checkout main" "$JJ/sub"
check deny  "git stash" "$JJ"
check deny  "git -c core.pager=cat reset --hard" "$JJ"
check deny  "cd $JJ && git rebase main" "$PLAIN"
check deny  "cd sub && git restore a.md" "$JJ"
check deny  "git -C $JJ commit -m x" "$PLAIN"
check deny  $'git commit -F - <<\'EOF\'\nfeat: x\nEOF' "$JJ"
check allow "git log -m -S'text' --oneline HEAD" "$JJ"
check allow "git show HEAD:a.md | head" "$JJ"
check allow "git diff HEAD" "$JJ"
check allow "git branch -a --contains abc123" "$JJ"
check allow "git commit -m x" "$PLAIN"
check allow "cd $PLAIN && git commit -m x" "$JJ"
check allow "git -C $PLAIN commit -m x" "$JJ"
check allow "cd \"\$OTHER\" && git commit -m x" "$JJ"
check allow "jj commit -m 'git commit'" "$JJ"
check allow "rg -n 'git commit' docs/" "$JJ"
check deny  "git add a.md" "$COLOCATED"
check deny  "git commit -m x" "$COLOCATED/sub"
check deny  "git add a.md" "$COLOCATED/.claude/worktrees"
check deny  "cd $COLOCATED && git add a.md" "$WORKTREE"
check deny  "git add a.md" "$JJ_WORKSPACE"
check allow "git add a.md" "$WORKTREE"
check allow "git commit -m x" "$WORKTREE/sub"
check allow "cd $WORKTREE && git commit -m x" "$COLOCATED"
check allow "git -C $WORKTREE/sub add a.md" "$COLOCATED"

# Guards parity with the z function in shell/zoxide.nix.
if command -v zoxide >/dev/null 2>&1; then
  export _ZO_DATA_DIR=$TMP/zoxide; mkdir -p "$_ZO_DATA_DIR"; zoxide add "$JJ" "$PLAIN"
  check deny  "z jj && git commit -m x" "$PLAIN"
  check allow "z plain && git commit -m x" "$JJ"
  check allow "z - && git commit -m x" "$JJ"
  check allow "z no-such-dir && git commit -m x" "$JJ"
  HOME=$JJ check deny "z && git stash" "$PLAIN"
else
  echo "skip: zoxide not on PATH, z rows not run"
fi

# Under zsh PIPESTATUS expands to nothing. Single-quoted and heredoc code runs in bash, where it works.
SHELL=/bin/zsh check deny  'nix build x 2>&1 | tail -5; echo "exit=${PIPESTATUS[0]}"'
SHELL=/bin/zsh check deny  'bun test | tee log; exit ${PIPESTATUS[0]}'
SHELL=/bin/zsh check allow 'nix build x 2>&1 | tail -5; echo "exit=${pipestatus[1]}"'
SHELL=/bin/zsh check allow "bash -c 'false | true; echo \${PIPESTATUS[0]}'"
SHELL=/bin/zsh check allow $'bash <<\'EOF\'\nfalse | true; echo ${PIPESTATUS[0]}\nEOF'
SHELL=/bin/bash check allow 'bun test | tee log; exit ${PIPESTATUS[0]}'

printf '%s/%s rows passed\n' "$((n - fail))" "$n"
[ "$fail" -eq 0 ]
