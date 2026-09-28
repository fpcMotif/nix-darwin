#!/usr/bin/env bash
# Bump OpenAI Codex release binaries in pkgs/codex.nix.
#
# Tracks the PRERELEASE channel: codex ships alphas ahead of stable and we want
# the bleeding edge, so this takes the newest release of any kind (the OpenAI
# curl installer and the GitHub "Latest" badge both stop at stable). Drop the
# `prerelease` arg below to fall back to latest-stable.
#
# SELF-HEAL re-published prereleases: OpenAI rebuilds and re-uploads the alpha
# assets IN PLACE — same `rust-v<ver>` tag, new binaries, new checksums. A
# version-only guard would never notice, leaving the four pinned fixed-output
# hashes stale; the darwin build then dies with `hash mismatch in fixed-output
# derivation` and `just switch` breaks while the nightly PR stays green (its
# Linux eval guard never realises the tarball). So --reverify re-downloads and
# re-pins every asset hash even when the version string is unchanged; a
# steady-state run leaves the tree clean.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

latest=$(au_latest_github_release openai/codex '^rust-v' prerelease)

assets=()
for triple in \
  aarch64-apple-darwin \
  x86_64-apple-darwin \
  aarch64-unknown-linux-musl \
  x86_64-unknown-linux-musl
do
  assets+=(--asset "https://github.com/openai/codex/releases/download/rust-v${latest}/codex-${triple}.tar.gz" "asset = \"codex-${triple}\";")
  assets+=(--asset "https://github.com/openai/codex/releases/download/rust-v${latest}/codex-code-mode-host-${triple}.tar.gz" "host.asset = \"codex-code-mode-host-${triple}\";")
done

au_bump_release --name codex --file pkgs/codex.nix --version "$latest" \
  --attr .#legacyPackages.aarch64-darwin.codex --reverify "${assets[@]}"
