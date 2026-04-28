# google-drive — Google Drive for desktop.
#
# Google does not publish a stable, version-pinned download URL for the macOS
# client: `dl.google.com/drive-file-stream/GoogleDrive.dmg` is the only public
# endpoint, and it always serves the current release (Homebrew's cask uses the
# same pattern with a `5-percent/` rollout cohort, but that's still "latest"-
# per-cohort, not version-pinned). We therefore record the current build number
# in `version` for tracking and keep the unversioned URL — every upstream
# release will require a manual hash bump.
#
# Bumping:
#   1. download the current DMG and read its build from the bundled plist:
#        H=$(nix-prefetch-url --name GoogleDrive.dmg https://dl.google.com/drive-file-stream/GoogleDrive.dmg)
#        # The build number can be read from the on-disk file in /nix/store, or
#        # by mounting the DMG on macOS:
#        #   hdiutil attach "$(nix-store --query --outputs $H)" -nobrowse -mountpoint /tmp/gd
#        #   /usr/libexec/PlistBuddy -c 'Print CFBundleVersion' \
#        #     /tmp/gd/Install\ Google\ Drive.app/Contents/Info.plist
#   2. update `version` below to that build number.
#   3. update `hash`:
#        nix hash convert --to sri --hash-algo sha256 "$H"

{
  lib,
  stdenv,
  fetchurl,
  undmg,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "google-drive";
  version = "0-unstable-2026-04-27";

  src = fetchurl {
    url = "https://dl.google.com/drive-file-stream/GoogleDrive.dmg";
    hash = "sha256-sq26uY6KME65Xjof9kuHABD8RFkXtgD0LIBEeGTgFig=";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";
  phases = [ "unpackPhase" "installPhase" ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    /usr/sbin/pkgutil --expand-full "GoogleDrive.pkg" expanded
    cp -R "expanded/GoogleDrive_arm64.pkg/Payload/Google Drive.app" "$out/Applications/"

    runHook postInstall
  '';

  meta = {
    description = "Google Drive client";
    homepage = "https://www.google.com/drive/";
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
    license = lib.licenses.unfree;
  };
})
