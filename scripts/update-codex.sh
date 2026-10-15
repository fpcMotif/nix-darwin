#!/usr/bin/env bash
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

# Any `rust-v` tag, not /releases/latest, because codex ships alphas ahead of
# stable and GitHub's "Latest" badge stops at stable.
latest=$(au_github_api "https://api.github.com/repos/openai/codex/releases?per_page=30" \
  | jq -r '.[].tag_name | select(test("^rust-v")) | sub("^rust-v"; "")' \
  | au_latest_semver)
release_url="https://github.com/openai/codex/releases/download/rust-v${latest}"

assets=()
for triple in \
  aarch64-apple-darwin \
  x86_64-apple-darwin \
  aarch64-unknown-linux-musl \
  x86_64-unknown-linux-musl
do
  assets+=(--asset "${release_url}/codex-${triple}.tar.gz" "asset = \"codex-${triple}\";")
  assets+=(--asset "${release_url}/codex-code-mode-host-${triple}.tar.gz" "host.asset = \"codex-code-mode-host-${triple}\";")
done

# OpenAI re-uploads alpha assets under the same tag. A stale hash breaks
# `just switch` while the nightly PR stays green, because its Linux eval never
# fetches the tarball.
au_bump_release --name codex --file pkgs/codex.nix --version "$latest" \
  --attr .#legacyPackages.aarch64-darwin.codex --reverify "${assets[@]}"
