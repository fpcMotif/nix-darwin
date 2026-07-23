# oh-my-pi — can1357/oh-my-pi (binary `omp`).
#
# Fork of pi-mono with hash-anchored edits, LSP, optimized tool harness,
# Python+browser+subagents extras. Coexists with `pi` (different binary name).
#
# Starting in v14.6.0 upstream stopped shipping a `.tar.gz` plus separate
# `pi_natives.<platform>.node` FFI module — the native code is now bundled
# into a single self-contained Bun standalone Mach-O binary, fetched directly.
#
# Bumping:
#   1. find current version:  curl -s https://api.github.com/repos/can1357/oh-my-pi/releases/latest | jq -r .tag_name
#   2. update `version` below.
#   3. update `hash`:
#        H=$(nix-prefetch-url https://github.com/can1357/oh-my-pi/releases/download/v<VER>/omp-darwin-arm64)
#        nix hash convert --to sri --hash-algo sha256 "$H"

{ lib
, stdenvNoCC
, fetchurl
,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "oh-my-pi";
  version = "17.0.8";

  src = fetchurl {
    url = "https://github.com/can1357/oh-my-pi/releases/download/v${finalAttrs.version}/omp-darwin-arm64";
    hash = "sha256-ctgYEiMLhvyxcNJze+AXOOeppK/NH0gBkZS/cgNNyck=";
  };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall

    install -Dm 755 $src $out/bin/omp

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
