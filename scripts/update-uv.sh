#!/usr/bin/env bash
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

latest=$(au_latest_github_release astral-sh/uv)
base="https://github.com/astral-sh/uv/releases/download/${latest}"

assets=()
for asset in \
  uv-aarch64-apple-darwin.tar.gz \
  uv-aarch64-unknown-linux-musl.tar.gz \
  uv-x86_64-unknown-linux-musl.tar.gz
do
  assets+=(--asset "${base}/${asset}" "asset = \"${asset}\";")
done

au_bump_release --name uv --file pkgs/uv-bin.nix --version "$latest" \
  --attr .#martin.uv-bin "${assets[@]}"
