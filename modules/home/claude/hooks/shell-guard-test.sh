#!/bin/bash
# Table test for shell-guard.sh: one row per command, expected verdict first.
# Run: bash shell-guard-test.sh [path/to/shell-guard.sh]  (the nix check passes the store path)
HOOK=${1:-$(dirname "$0")/shell-guard.sh}
fail=0; n=0
check() {
  want=$1; cmd=$2; n=$((n + 1))
  out=$(jq -cn --arg c "$cmd" '{tool_name:"Bash",tool_input:{command:$c}}' | bash "$HOOK" 2>&1 >/dev/null); rc=$?
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
check deny  "perl -pi -e 's/a/b/' file.ts"
check deny  "perl -i -pe 's/a/b/' file.ts"
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
check deny  "cat file.ts"
check deny  "cat -n file.ts | head -n 40"
check deny  "x=\$(cat VERSION)"
check deny  "find . -name '*.ts' -not -path '*/node_modules/*'"
check deny  "perl -pe 's/a/b/' file.ts"
check deny  "rg -l PAT src | xargs perl -ne 'print if /x/'"
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

printf '%s/%s rows passed\n' "$((n - fail))" "$n"
[ "$fail" -eq 0 ]
