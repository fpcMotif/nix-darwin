# raycast — Raycast launcher.
#
# Pin to a versioned download endpoint instead of `api.raycast.app/v2/download`,
# which silently serves "latest" and invalidates the content hash on every
# upstream release. `releases.raycast.com/releases/<version>/download` redirects
# to a version-pinned R2 object (the underlying file is stable as long as
# `version` is fixed; only the per-request signature on the redirect changes).
#
# Bumping:
#   1. find current version:
#        curl -s 'https://releases.raycast.com/releases/latest?build=universal' | jq -r .version
#   2. update `version` below.
#   3. update `hash`:
#        H=$(nix-prefetch-url "https://releases.raycast.com/releases/<VER>/download?build=universal")
#        nix hash convert --to sri --hash-algo sha256 "$H"

{
  lib,
  stdenv,
  fetchurl,
  undmg,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "raycast";
  version = "1.104.13";

  src = fetchurl {
    url = "https://releases.raycast.com/releases/${finalAttrs.version}/download?build=universal";
    name = "Raycast.dmg";
    hash = "sha256-27kvr1ilsjmYYiZnffJO8U5GFwpM82hc/DoBcgE+Lrc=";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";
  phases = [ "unpackPhase" "installPhase" ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    cp -R "Raycast.app" "$out/Applications/"

    runHook postInstall
  '';

  meta = {
    description = "Raycast launcher";
    homepage = "https://www.raycast.com";
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
    license = lib.licenses.unfree;
  };
})
