#!/usr/bin/env bash
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

latest=$(au_github_api "https://api.github.com/repos/dmtrKovalenko/fff/releases?per_page=30" \
  | jq -r '[.[]
      | select(.draft | not)
      | select(.tag_name | test("^[0-9]+\\.[0-9]+\\.[0-9]+-nightly\\.[0-9a-f]+$"))]
    | sort_by(.published_at) | last | .tag_name // ""')
if [ -z "$latest" ]; then
  echo "fff-mcp: no dated nightly release found" >&2
  exit 1
fi
base="https://github.com/dmtrKovalenko/fff/releases/download/${latest}"

assets=()
for asset in \
  fff-mcp-aarch64-apple-darwin \
  fff-mcp-x86_64-apple-darwin \
  fff-mcp-aarch64-unknown-linux-gnu \
  fff-mcp-x86_64-unknown-linux-gnu
do
  assets+=(--asset "${base}/${asset}" "asset = \"${asset}\";")
done

au_bump_release --name fff-mcp --file pkgs/fff-mcp.nix --version "$latest" \
  --attr .#martin.fff-mcp "${assets[@]}"
