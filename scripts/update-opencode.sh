#!/usr/bin/env bash
# Bump opencode CLI in lockstep with the upstream `sst/opencode` release.
#
# Hashes are computed via `nix-prefetch-url` per platform asset (works on
# any host OS), so the lockfile is never left with stub hashes after a
# partial update.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE_CLI="pkgs/opencode.nix"

latest=$(au_latest_github_release sst/opencode)
current=$(au_current_version "$FILE_CLI")
if [ "$current" = "$latest" ]; then
  echo "opencode already at $latest"; exit 0
fi

au_set_version "$FILE_CLI" "$latest"

declare -A cli_assets=(
  [opencode-darwin-arm64.zip]=aarch64-darwin
  [opencode-linux-x64.tar.gz]=x86_64-linux
  [opencode-linux-arm64.tar.gz]=aarch64-linux
)

# Prefetch every platform asset concurrently into its own tempfile (network is
# the bottleneck). Each job writes a distinct file, so there is no write race;
# the in-place lockfile edits run sequentially after the wait barrier.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
pids=()

for asset in "${!cli_assets[@]}"; do
  url="https://github.com/sst/opencode/releases/download/v${latest}/${asset}"
  echo "  cli: $asset"
  (au_prefetch_sri "$url" > "$work/cli_$asset") &
  pids+=($!)
done

# Under set -e a failed prefetch makes wait return non-zero and aborts before
# any stub hash can be applied.
for pid in "${pids[@]}"; do
  wait "$pid"
done

for asset in "${!cli_assets[@]}"; do
  # Anchor on the URL substring so platform blocks never collide.
  au_set_block_hash "$FILE_CLI" "/${asset}\"" "$(cat "$work/cli_$asset")"
done

au_build .#martin.opencode
au_report_change opencode "$current" "$latest"
