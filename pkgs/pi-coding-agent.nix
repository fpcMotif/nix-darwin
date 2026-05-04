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
# Why we wrap with NPM_CLIENT=bun:
#   pi 0.71.0 spawns an npm client at startup to discover globally-installed
#   pi extensions. By default it looks for a `pi-npm-bun` binary, which the
#   release tarball does NOT ship — so plain `pi` crashes before the prompt
#   renders. pi exposes an `NPM_CLIENT` env var ("Absolute path to the npm
#   client executable") that overrides this lookup, so we wrap `pi` to point
#   directly at the nix-managed `bun` binary. No fake `pi-npm-bun` shim,
#   no PATH manipulation, no $HOME-relative hardcoding — pi uses its own
#   declared override mechanism.
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
, makeWrapper
, bun
,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "pi-coding-agent";
  version = "0.72.1";

  src = fetchurl {
    url = "https://github.com/badlogic/pi-mono/releases/download/v${finalAttrs.version}/pi-darwin-arm64.tar.gz";
    hash = "sha256-QLLwJ/wPWBMXBykhvy593+yHHDpOlLc8Odc/wqvF5Rc=";
  };

  sourceRoot = "pi";

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true; # don't strip a Bun-compiled standalone
  dontPatchELF = true; # macOS, but be explicit

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/pi-coding-agent $out/bin
    cp -R . $out/libexec/pi-coding-agent/
    chmod +x $out/libexec/pi-coding-agent/pi

    # Wrap with NPM_CLIENT pointing at bun so pi 0.71.0's startup
    # `getGlobalNpmRoot` lookup resolves cleanly. --set-default lets the
    # user still override at runtime if they want a different client.
    makeWrapper $out/libexec/pi-coding-agent/pi $out/bin/pi \
      --set-default NPM_CLIENT ${bun}/bin/bun

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
