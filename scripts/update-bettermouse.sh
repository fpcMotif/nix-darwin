#!/usr/bin/env bash
# Bump better-mouse.com/BetterMouse.app in pkgs/bettermouse.nix.
#
# BetterMouse has no GitHub releases — the upstream "release notes" RSS feed
# is the canonical source of the current version string. Each post is titled
# `Version <x.y.zzzz>`, so the topmost <title> entry that matches that
# pattern is the latest build.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/bettermouse.nix"

latest=$(
  curl -fsSL "https://better-mouse.com/feed/" \
    | grep -oE '<title>Version [0-9.]+</title>' \
    | head -1 \
    | sed -E 's|<title>Version ([0-9.]+)</title>|\1|'
)
[ -n "$latest" ] || { echo "bettermouse: could not scrape latest version" >&2; exit 1; }

current=$(au_current_version "$FILE")
if [ "$current" = "$latest" ]; then
  echo "bettermouse already at $latest"; exit 0
fi
echo "bettermouse: $current -> $latest"

url="https://better-mouse.com/wp-content/uploads/BetterMouse.${latest}.zip"
sri=$(au_prefetch_sri "$url")

au_set_version "$FILE" "$latest"
au_inplace_sed "$FILE" -e "s|hash = \"sha256-[^\"]*\"|hash = \"${sri}\"|"

au_build .#martin.bettermouse
echo "bettermouse bumped to $latest"
