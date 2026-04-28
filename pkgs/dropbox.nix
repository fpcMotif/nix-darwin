# dropbox — Dropbox client.
#
# Pin to the version-tagged DMG on `edge.dropboxstatic.com` instead of
# `dropbox.com/download?plat=mac&full=1`, which 302s to whatever the current
# release is and invalidates the content hash on every upstream release. The
# `Dropbox <version>.dmg` filenames on `edge.dropboxstatic.com` are immutable
# per release.
#
# Bumping:
#   1. find current version (the redirect target carries it):
#        curl -sIL 'https://www.dropbox.com/download?plat=mac&full=1' \
#          | awk -F'Dropbox%20|.dmg' '/^location:.*Dropbox%20/{print $2; exit}'
#   2. update `version` below.
#   3. update `hash`:
#        H=$(nix-prefetch-url "https://edge.dropboxstatic.com/dbx-releng/client/Dropbox%20<VER>.dmg")
#        nix hash convert --to sri --hash-algo sha256 "$H"

{
  lib,
  stdenv,
  fetchurl,
  undmg,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "dropbox";
  version = "248.4.3576";

  src = fetchurl {
    url = "https://edge.dropboxstatic.com/dbx-releng/client/Dropbox%20${finalAttrs.version}.dmg";
    name = "Dropbox.dmg";
    hash = "sha256-pIKS73MwH9SBXg39zqevGxcHXbK0jFjz+onWhG4/E3g=";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";
  phases = [ "unpackPhase" "installPhase" ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    cp -R "Dropbox.app" "$out/Applications/"

    runHook postInstall
  '';

  meta = {
    description = "Dropbox client";
    homepage = "https://www.dropbox.com";
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
    license = lib.licenses.unfree;
  };
})
