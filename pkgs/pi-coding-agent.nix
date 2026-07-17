# pi-coding-agent — @mariozechner/pi-coding-agent (binary `pi`).
#
# Why prebuilt binary, not buildNpmPackage:
#   The npm package `@mariozechner/pi-coding-agent` lives inside the pi-mono
#   monorepo (badlogic/pi-mono, now mirrored at earendil-works/pi-mono).
#   buildNpmPackage from a workspace-root would need the full monorepo's
#   package-lock.json plus a workspace-aware build step, and the published
#   npm tarball has no lock file. Upstream already ships a `bun build
#   --compile`'d single-file Mach-O binary in their GitHub release. Fetching
#   that and wrapping it is more reliable than reproducing the bun bundle
#   ourselves and matches how nixpkgs handles `bun`, `deno`, etc.
#
# Layout inside the tarball (sourceRoot = "pi"):
#   pi               — arm64 Mach-O (Bun standalone)
#   photon_rs_bg.wasm — required at runtime
#   theme/, assets/, docs/, examples/, export-html/, package.json, ...
#
# npm client resolution (pi 0.72+):
#   pi reads `npmCommand` from `~/.pi/agent/settings.json` (argv-style array)
#   to locate globally-installed pi extensions at startup. The default is
#   `npm`, which nixpkgs provides via `nodejs-slim`, so an unconfigured user
#   gets a working `pi` out of the box. To use bun's global cache instead,
#   set `"npmCommand": ["bun"]` in settings.json — pi special-cases the
#   string `"bun"` and runs `bun pm bin -g`. The pre-0.72 `NPM_CLIENT` env
#   var override no longer applies; do not reintroduce a wrapper for it.
#
# Bumping:
#   1. find current version:  curl -s https://api.github.com/repos/badlogic/pi-mono/releases/latest | jq -r .tag_name
#   2. update `version` below.
#   3. update `hash`:
#        H=$(nix-prefetch-url https://github.com/badlogic/pi-mono/releases/download/v<VER>/pi-darwin-arm64.tar.gz)
#        nix hash convert --to sri --hash-algo sha256 "$H"

{ lib
, stdenvNoCC
, fetchurl
,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "pi-coding-agent";
  version = "0.80.10";

  src = fetchurl {
    url = "https://github.com/badlogic/pi-mono/releases/download/v${finalAttrs.version}/pi-darwin-arm64.tar.gz";
    hash = "sha256-RAbtInxIby48Fs8U95PcOtRrXQG/aRNaJCTP+lipo0s=";
  };

  sourceRoot = "pi";

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true; # don't strip a Bun-compiled standalone
  dontPatchELF = true; # macOS, but be explicit

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
