# pi-coding-agent — @mariozechner/pi-coding-agent (binary `pi`).
#
# Why prebuilt binary, not buildNpmPackage:
#   The npm package `@mariozechner/pi-coding-agent` lives inside the pi-mono
#   monorepo (badlogic/pi-mono). buildNpmPackage from a workspace-root would
#   need the full monorepo's package-lock.json plus a workspace-aware build
#   step, and the published npm tarball has no lock file. Upstream already
#   ships a `bun build --compile`'d single-file Mach-O binary in their GitHub
#   release. Fetching that and wrapping it is more reliable than reproducing
#   the bun bundle ourselves and matches how nixpkgs handles `bun`, `deno`,
#   etc.
#
# Layout inside the tarball (sourceRoot = "pi"):
#   pi               — 70MB arm64 Mach-O (Bun standalone)
#   photon_rs_bg.wasm — required at runtime
#   theme/, assets/, docs/, examples/, export-html/, package.json, ...
#
# The Bun runtime resolves siblings via process.execPath. Symlinking
# $out/bin/pi -> $out/libexec/pi-coding-agent/pi keeps the binary next to
# its assets while still putting `pi` on PATH.
#
# Bumping:
#   1. find current version:  curl -s https://api.github.com/repos/badlogic/pi-mono/releases/latest | jq -r .tag_name
#   2. update `version` below.
#   3. update `hash`:
#        H=$(nix-prefetch-url https://github.com/badlogic/pi-mono/releases/download/v<VER>/pi-darwin-arm64.tar.gz)
#        nix hash convert --to sri --hash-algo sha256 "$H"

{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "pi-coding-agent";
  version = "0.70.2";

  src = fetchurl {
    url = "https://github.com/badlogic/pi-mono/releases/download/v${finalAttrs.version}/pi-darwin-arm64.tar.gz";
    hash = "sha256-TgOQUDZ9gr/5Y+Ff6o2FyiaPewKEuD9fFZOarQhzU6Q=";
  };

  sourceRoot = "pi";

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;     # don't strip a Bun-compiled standalone
  dontPatchELF = true;  # macOS, but be explicit

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/pi-coding-agent $out/bin
    cp -R . $out/libexec/pi-coding-agent/
    chmod +x $out/libexec/pi-coding-agent/pi
    ln -s $out/libexec/pi-coding-agent/pi $out/bin/pi

    runHook postInstall
  '';

  meta = {
    description = "Coding-agent CLI with read/bash/edit/write tools (pi-mono)";
    homepage = "https://github.com/badlogic/pi-mono";
    changelog = "https://github.com/badlogic/pi-mono/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "pi";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
