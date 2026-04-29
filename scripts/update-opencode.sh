#!/usr/bin/env bash
# Bump opencode CLI + Electron desktop by polling sst/opencode GitHub
# releases. Both pkgs/opencode.nix and pkgs/opencode-electron.nix share the
# same upstream version; we update them in lockstep.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FILE_CLI="pkgs/opencode.nix"
FILE_ELECTRON="pkgs/opencode-electron.nix"
FAKE='sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='

latest=$(curl -fsSL https://api.github.com/repos/sst/opencode/releases/latest \
  | jq -r '.tag_name // ""' | sed 's/^v//')
[ -n "$latest" ] || { echo "could not fetch sst/opencode latest tag" >&2; exit 1; }

current=$(grep -oE 'version = "[^"]+"' "$FILE_CLI" | head -1 | cut -d'"' -f2)
if [ "$current" = "$latest" ]; then
  echo "opencode already at $latest"; exit 0
fi
echo "opencode: $current -> $latest"

# Stage both files with FAKE hashes + new version literal.
for f in "$FILE_CLI" "$FILE_ELECTRON"; do
  sed -i.bak \
    -e "s|version = \"[^\"]*\"|version = \"${latest}\"|" \
    -e "s|hash = \"sha256-[^\"]*\"|hash = \"${FAKE}\"|g" \
    "$f"
done

discover() {
  local pkgname="$1"
  set +e
  log=$(nix build ".#martin.${pkgname}" --no-link 2>&1)
  set -e
  printf '%s\n' "$log" | grep -oE 'got:[[:space:]]+sha256-[A-Za-z0-9+/=]+' \
    | head -1 | sed -E 's/got:[[:space:]]+//'
}

# CLI: native platform only — daily CI runs on linux, dev runs on darwin;
# both will see "their" platform's hash filled in. The remaining FAKE entries
# get bumped on subsequent runs from other platforms or via a manual sweep.
got=$(discover opencode)
[ -n "$got" ] || { echo "no hash extracted for opencode CLI" >&2; exit 1; }
sed -i.bak2 "0,/${FAKE}/{s|${FAKE}|${got}|}" "$FILE_CLI"
nix build .#martin.opencode --no-link

got=$(discover opencode-electron)
if [ -n "$got" ]; then
  sed -i.bak2 "0,/${FAKE}/{s|${FAKE}|${got}|}" "$FILE_ELECTRON"
  nix build .#martin.opencode-electron --no-link
else
  echo "opencode-electron: no hash discovered (probably not built on this platform); leaving FAKE for next platform's CI run"
fi

rm -f "$FILE_CLI".bak* "$FILE_ELECTRON".bak*
echo "opencode bumped to $latest"
