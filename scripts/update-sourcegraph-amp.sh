#!/usr/bin/env bash
# Bump @sourcegraph/amp in pkgs/sourcegraph-amp.nix and pkgs/sourcegraph-amp/.
#
# Strategy: bump package.json, regenerate package-lock.json, bump the `version`
# line in the .nix file. No npmDepsHash to manage — `importNpmLock` derives the
# fixed-output deps from the lockfile at eval time.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/sourcegraph-amp.nix"
PKG_DIR="pkgs/sourcegraph-amp"

# Track amp's stable `latest` dist-tag, NOT au_latest_npm's bleeding-edge
# priority list. Amp's `next` tag is a `-singleexe` side-channel whose build
# timestamp currently trails `latest`, so the priority list would pin us to an
# OLDER build and revert manual bumps on the next nightly run. `latest` is
# amp's stable release channel and matches what `amp` self-updates to.
latest=$(curl -fsSL "https://registry.npmjs.org/@sourcegraph%2famp" \
           | jq -r '."dist-tags".latest // ""')
[ -n "$latest" ] && [ "$latest" != null ] || {
  echo "update-sourcegraph-amp: empty latest dist-tag" >&2; exit 1
}
current=$(au_current_version "$FILE")
if [ "$current" = "$latest" ]; then
  echo "sourcegraph-amp already at $latest"; exit 0
fi

# Update the package.json pin and regenerate the lockfile. Use npm from Nix
# rather than the PATH shim: Bun's `npm` writes bun.lock instead of the lock
# file Nix consumes. Nixpkgs splits npm from the Node runtime, so resolve both
# outputs explicitly and keep a fallback for older channel revisions that
# embedded the CLI under lib/node_modules.
nodejs_out=$(nix eval --raw nixpkgs#nodejs-slim_26.outPath)
npm_out=$(nix eval --raw nixpkgs#nodejs-slim_26.npm.outPath)
npm_cmd=("$npm_out/bin/npm")
if [ ! -x "${npm_cmd[0]}" ]; then
  npm_cli="$nodejs_out/lib/node_modules/npm/bin/npm-cli.js"
  if [ ! -x "$nodejs_out/bin/node" ] || [ ! -f "$npm_cli" ]; then
    echo "update-sourcegraph-amp: Nix Node 26 npm output not found" >&2
    exit 1
  fi
  npm_cmd=("$nodejs_out/bin/node" "$npm_cli")
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
jq --arg v "$latest" '.dependencies."@sourcegraph/amp" = $v' \
  "$PKG_DIR/package.json" > "$work/package.json"

# Node does not read the macOS Keychain by default. The system PEM includes
# locally trusted proxy roots; Linux runners use the same conventional path.
ca_file=/etc/ssl/cert.pem
if [ ! -f "$ca_file" ]; then
  ca_out=$(nix eval --raw nixpkgs#cacert.outPath)
  ca_file="$ca_out/etc/ssl/certs/ca-bundle.crt"
fi
(cd "$work" && NODE_EXTRA_CA_CERTS="$ca_file" \
  "${npm_cmd[@]}" install --package-lock-only --omit=peer >/dev/null)

mv "$work/package.json" "$PKG_DIR/package.json"
mv "$work/package-lock.json" "$PKG_DIR/package-lock.json"

au_set_version "$FILE" "$latest"

au_build .#martin.sourcegraph-amp
au_report_change sourcegraph-amp "$current" "$latest"
