#!/usr/bin/env bash
# Bump opencode CLI + Electron desktop by polling sst/opencode GitHub
# releases. Both pkgs/opencode.nix and pkgs/opencode-electron.nix share the
# same upstream version; we update them in lockstep.
set -euo pipefail
IFS=$'\n\t'
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FILE_CLI="pkgs/opencode.nix"
FILE_ELECTRON="pkgs/opencode-electron.nix"
FAKE='sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
CLI_SYSTEMS=(aarch64-darwin x86_64-linux aarch64-linux)
ELECTRON_SYSTEMS=(aarch64-darwin)

latest=$(curl -fsSL https://api.github.com/repos/sst/opencode/releases/latest \
  | jq -r '.tag_name // ""' | sed 's/^v//')
[ -n "$latest" ] || { echo "could not fetch sst/opencode latest tag" >&2; exit 1; }

current=$(grep -oE 'version = "[^"]+"' "$FILE_CLI" | head -1 | cut -d'"' -f2)
if [ "$current" = "$latest" ]; then
  echo "opencode already at $latest"
  exit 0
fi
echo "opencode: $current -> $latest"

# Stage both files with FAKE hashes + new version literal.
for f in "$FILE_CLI" "$FILE_ELECTRON"; do
  sed -i.bak \
    -e "s|version = \"[^\"]*\"|version = \"${latest}\"|" \
    -e "s|hash = \"sha256-[^\"]*\"|hash = \"${FAKE}\"|g" \
    "$f"
done

platform_url() {
  local file="$1"
  local platform="$2"

  awk -v plat="$platform" '
    $0 ~ "\\\"" plat "\\\" = " { in_block = 1 }
    in_block && match($0, /url = "[^"]+";/) {
      line = substr($0, RSTART, RLENGTH)
      sub(/^url = "/, "", line)
      sub(/";$/, "", line)
      print line
      exit
    }
  ' "$file"
}

replace_platform_hash() {
  local file="$1"
  local system="$2"
  local hash="$3"
  local tmp

  tmp=$(mktemp "${file}.XXXXXX")
  awk -v plat="$system" -v fake="$FAKE" -v real="$hash" '
    $0 ~ "\\\"" plat "\\\" = " { in_block = 1 }
    in_block && index($0, fake) {
      sub(fake, real)
      in_block = 0
    }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

prefetch_platform_hash() {
  local file="$1"
  local system="$2"
  local url

  url=$(platform_url "$file" "$system")
  [ -n "$url" ] || { echo "no URL found for opencode $system in $file" >&2; exit 1; }
  url="${url//\$\{version\}/$latest}"
  nix store prefetch-file --json "$url" | jq -r '.hash // ""'
}

for system in "${CLI_SYSTEMS[@]}"; do
  got=$(prefetch_platform_hash "$FILE_CLI" "$system")
  [ -n "$got" ] || { echo "no opencode CLI hash extracted for $system" >&2; exit 1; }
  replace_platform_hash "$FILE_CLI" "$system" "$got"
done

for system in "${ELECTRON_SYSTEMS[@]}"; do
  got=$(prefetch_platform_hash "$FILE_ELECTRON" "$system")
  [ -n "$got" ] || { echo "no opencode Electron hash extracted for $system" >&2; exit 1; }
  replace_platform_hash "$FILE_ELECTRON" "$system" "$got"
done

if grep -q "$FAKE" "$FILE_CLI" "$FILE_ELECTRON"; then
  echo "one or more opencode hashes are still fake" >&2
  exit 1
fi

nix build .#martin.opencode --no-link
native_system=$(nix eval --raw --impure --expr 'builtins.currentSystem')
if [ "$native_system" = "aarch64-darwin" ]; then
  nix build .#martin.opencode-electron --no-link
fi

rm -f "$FILE_CLI".bak* "$FILE_ELECTRON".bak*
echo "opencode bumped to $latest"
