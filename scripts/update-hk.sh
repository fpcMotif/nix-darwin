#!/usr/bin/env bash
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

latest=$(au_latest_github_release jdx/hk)
base="https://github.com/jdx/hk/releases/download/v${latest}"

assets=()
for asset in \
  hk-aarch64-apple-darwin.tar.gz \
  hk-aarch64-unknown-linux-musl.tar.gz \
  hk-x86_64-unknown-linux-musl.tar.gz
do
  assets+=(--asset "${base}/${asset}" "asset = \"${asset}\";")
done

au_bump_release --name hk --file pkgs/hk-bin.nix --version "$latest" \
  --attr .#martin.hk-bin "${assets[@]}"
