# oh-my-pi — can1357/oh-my-pi (binary `omp`).
#
# Fork of pi-mono with hash-anchored edits, LSP, optimized tool harness,
# Python+browser+subagents extras. Coexists with `pi` (different binary name).
#
# Same packaging strategy as pi-coding-agent: upstream already publishes a
# `bun build --compile`'d standalone binary per release. We fetch that.
#
# Layout inside the tarball (sourceRoot = "."):
#   omp                          — Bun standalone arm64 Mach-O
#   pi_natives.darwin-arm64.node — native FFI module loaded at runtime
#
# The .node module is loaded relative to the binary's resolved path, so we
# keep both in $out/libexec/oh-my-pi/ and surface only the symlink in
# $out/bin/omp.
#
# Bumping:
#   1. find current version:  curl -s https://api.github.com/repos/can1357/oh-my-pi/releases/latest | jq -r .tag_name
#   2. update `version` below.
#   3. update `hash`:
#        H=$(nix-prefetch-url https://github.com/can1357/oh-my-pi/releases/download/v<VER>/omp-darwin-arm64.tar.gz)
#        nix hash convert --to sri --hash-algo sha256 "$H"

{ lib
, stdenvNoCC
, fetchurl
,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "oh-my-pi";
  version = "14.2.1";

  src = fetchurl {
    url = "https://github.com/can1357/oh-my-pi/releases/download/v${finalAttrs.version}/omp-darwin-arm64.tar.gz";
    hash = "sha256-yN/yjuedr7VhnHUw5LVAGSo7/RYW9/HDYl2xgstcirg=";
  };

  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/oh-my-pi $out/bin
    install -m 755 omp $out/libexec/oh-my-pi/omp
    install -m 644 pi_natives.darwin-arm64.node $out/libexec/oh-my-pi/
    ln -s $out/libexec/oh-my-pi/omp $out/bin/omp

    runHook postInstall
  '';

  meta = {
    description = "AI coding agent for the terminal (oh-my-pi fork of pi-mono)";
    homepage = "https://github.com/can1357/oh-my-pi";
    changelog = "https://github.com/can1357/oh-my-pi/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "omp";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
