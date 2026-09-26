# Bun — canary channel, prebuilt binary.
#
# Why this exists: `bun upgrade` rewrites its own executable in place, which
# fails on Nix because the running binary lives in the read-only /nix/store
# (EACCES: "Failed to move new version of Bun to /nix/store/…/bin/bun"). The
# Nix-native way to follow bun's bleeding-edge `canary` channel is to fetch a
# prebuilt canary binary, as pkgs/zed-nightly-bin.nix does for Zed.
# Updates land via scripts/update-bun-canary.sh (nightly, through
# .github/workflows/auto-update.yml).
#
# Source: a release pin on bun's npm canary. Once a day bun publishes
# @oven/bun-darwin-aarch64@<last stable>-canary.<YYYYMMDD>.<n> under the npm
# `canary` dist-tag. npm versions are immutable, so the hash below stays valid
# on every machine and every CI run. The binary inside is byte-identical to the
# GitHub `canary` release asset built from the same commit (checked on
# 1.4.2-canary.20260925.1, commit 29d9638da).
#
# Not the GitHub `canary` release: bun re-uploads
# releases/download/canary/bun-darwin-aarch64.zip at one URL several times a
# day. A hash pinned to it went stale within hours, so the darwin CI job, often
# queued for longer than that, failed with a fixed-output hash mismatch even
# right after a repin. Any `just switch` without the old zip in its store
# failed the same way.
#
# npm published no canary from 2026-05-19 to 2026-08-20, which is why this pin
# once used the GitHub asset. The updater now fails when npm's newest canary
# is over a week old, so a stall shows in the nightly run.
#
# Version naming: npm names a canary after the last stable release, while the
# binary reports the next patch. `bun --revision` on 1.4.2-canary.20260925.1
# prints 1.4.3-canary.1+29d9638da.
#
# Output shape mirrors nixpkgs `bun`: $out/bin/bun plus $out/bin/bunx -> bun.
# The bunx symlink backs the `npx = "bunx"` alias in modules/home/shell/zsh.nix.
#
# Platforms: aarch64-darwin only, matching flake.nix's supportedSystems. Add
# x86_64-darwin / linux here AND in supportedSystems AND in build.yml's runner
# matrix if those become targets (npm packages: @oven/bun-darwin-x64,
# @oven/bun-linux-x64, @oven/bun-linux-aarch64).

{ lib
, stdenvNoCC
, fetchurl
}:

let
  version = "1.4.2-canary.20260925.1";

  sources = {
    "aarch64-darwin" = {
      url = "https://registry.npmjs.org/@oven/bun-darwin-aarch64/-/bun-darwin-aarch64-${version}.tgz";
      hash = "sha256-UoYq09wLpwelR2Q4Mme6bQb9oqKyZYxt7SxFfOBAIbY=";
    };
  };

  system = stdenvNoCC.hostPlatform.system;
  source = sources.${system} or (throw "bun-canary-bin: unsupported system ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "bun-canary-bin";
  inherit version;

  src = fetchurl { inherit (source) url hash; };

  # Stripping would rewrite the Mach-O and break bun's code signature, so leave
  # the downloaded binary byte-for-byte intact — the same bytes `bun upgrade`
  # would have placed.
  dontStrip = true;

  # The npm tarball unpacks to package/ (the default sourceRoot), which holds
  # bin/bun beside package.json and README.md.
  installPhase = ''
    runHook preInstall
    install -Dm755 bin/bun "$out/bin/bun"
    ln -s bun "$out/bin/bunx"
    runHook postInstall
  '';

  meta = {
    description = "Bun — prebuilt canary channel binary";
    homepage = "https://bun.sh/";
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "bun";
  };
}
