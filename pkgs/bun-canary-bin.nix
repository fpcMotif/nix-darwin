# Bun — canary channel, prebuilt binary.
#
# Why this exists: `bun upgrade` rewrites its own executable in place, which
# fails on Nix because the running binary lives in the read-only /nix/store
# (EACCES: "Failed to move new version of Bun to /nix/store/…/bin/bun"). The
# Nix-native way to follow bun's bleeding-edge `canary` channel is to fetch the
# prebuilt release asset, exactly as pkgs/zed-nightly-bin.nix does for Zed.
# Updates land via scripts/update-bun-canary.sh (hourly, through
# .github/workflows/auto-update.yml).
#
# Rolling tag: bun force-pushes the `canary` git tag in place, so there is no
# per-build download URL — `url` is the rolling canary asset and the pin is the
# zip's sha256. The updater is HASH-driven (re-prefetches the rolling URL and
# diffs the sha256) because no cross-platform API reports the live canary
# semver: npm's `canary` dist-tag lags weeks behind (it read 1.3.13-canary
# while the tag already served 1.4.0-canary). The `version` below is parsed out
# of the binary's own bytes by the updater and is informational only.
#
# Output shape mirrors nixpkgs `bun`: $out/bin/bun plus $out/bin/bunx -> bun.
# The bunx symlink backs the `npx = "bunx"` alias in modules/home/zsh.nix.
#
# Platforms: aarch64-darwin only, matching flake.nix's supportedSystems. Add
# x86_64-darwin / linux here AND in supportedSystems AND in build.yml's runner
# matrix if those become targets (assets: bun-darwin-x64.zip, bun-linux-x64.zip,
# bun-linux-aarch64.zip).

{ lib
, stdenvNoCC
, fetchurl
, unzip
}:

let
  version = "1.4.0-canary.1+f12e9f9d8";

  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/oven-sh/bun/releases/download/canary/bun-darwin-aarch64.zip";
      hash = "sha256-cPNTxpu7kcnCryDCf2XO8ehj37ZxAimvOFEpAEiYyvs=";
    };
  };

  system = stdenvNoCC.hostPlatform.system;
  source = sources.${system} or (throw "bun-canary-bin: unsupported system ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "bun-canary-bin";
  inherit version;

  src = fetchurl { inherit (source) url hash; };

  nativeBuildInputs = [ unzip ];

  # The asset is a flat zip (bun-<target>/bun); stay at the extraction root and
  # let installPhase locate the binary so this is robust to the inner dir name.
  sourceRoot = ".";

  # Stripping would rewrite the Mach-O and break bun's code signature, so leave
  # the downloaded binary byte-for-byte intact — the same bytes `bun upgrade`
  # would have placed.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    bin="$(find . -maxdepth 2 -name bun -type f -print -quit)"
    test -n "$bin" || {
      echo "bun-canary-bin: no bun binary in canary zip" >&2
      ls -R >&2
      exit 1
    }
    install -Dm755 "$bin" "$out/bin/bun"
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
