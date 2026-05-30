#!/usr/bin/env bash
# Bump OpenAI Codex release binaries in pkgs/codex.nix.
#
# Tracks the PRERELEASE channel: codex ships alphas ahead of stable and we want
# the bleeding edge, so this takes the newest release of any kind (the OpenAI
# curl installer and the GitHub "Latest" badge both stop at stable). Drop the
# `prerelease` arg below to fall back to latest-stable.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/codex.nix"

latest=$(au_latest_github_release openai/codex '^rust-v' prerelease)
current=$(au_current_version "$FILE")
if [ "$current" = "$latest" ]; then
  echo "codex already at $latest"; exit 0
fi
echo "codex: $current -> $latest"

au_set_version "$FILE" "$latest"

assets=(
  codex-aarch64-apple-darwin
  codex-x86_64-apple-darwin
  codex-aarch64-unknown-linux-musl
  codex-x86_64-unknown-linux-musl
)

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
pids=()

for asset in "${assets[@]}"; do
  url="https://github.com/openai/codex/releases/download/rust-v${latest}/${asset}.tar.gz"
  # Prefetch concurrently into distinct tempfiles so there is no write race.
  (au_prefetch_sri "$url" > "$work/$asset") &
  pids+=($!)
done

# Under set -e a failed prefetch makes wait return non-zero and aborts before
# any stub hash can be applied.
for pid in "${pids[@]}"; do
  wait "$pid"
done

for asset in "${assets[@]}"; do
  au_set_block_hash "$FILE" "asset = \"${asset}\";" "$(cat "$work/$asset")"
done

echo "codex bumped to $latest"
