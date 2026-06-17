# Zed editor — nightly channel, prebuilt binary.
#
# Why this exists: `inputs.zed-upstream` (github:zed-industries/zed) is the
# raw source tree. Building `packages.${system}.default` recompiles ~3000
# cargo crates with no cache.nixos.org hits — a multi-hour catastrophe.
# Zed publishes prebuilt `.dmg` artifacts for every nightly commit on
# `zed-nightly-host.nyc3.digitaloceanspaces.com`; this derivation just
# fetches and unpacks one. Updates land via `scripts/update-zed-nightly.sh`.
#
# Why _7zz, not undmg: Zed ships APFS-format DMGs and `undmg` 1.1.0 only
# handles legacy HFS+. `_7zz` (p7zip-26 from nixpkgs) extracts both.
#
# Output shape mirrors nixpkgs `zed-editor`:
#   $out/Applications/Zed Nightly.app
#   $out/bin/zeditor -> ../Applications/<app>/Contents/MacOS/cli
#
# That layout is what `programs.zed-editor` in home-manager expects, so it
# drops in as `programs.zed-editor.package = pkgs.martin.zed-nightly-bin`.
#
# Platforms: aarch64-darwin only. flake.nix's `supportedSystems` skips
# x86_64-darwin, so a Darwin/x86_64 pin would never reach CI or any host
# config — having one would just create a silent rot risk (Zed's nightly
# host can stop publishing the asset, the prefetched hash can go stale
# and nothing would notice). Add x86_64-darwin back here AND in the flake's
# supportedSystems list AND in build.yml's runner matrix if Intel-Mac
# support becomes a goal.

{ lib
, stdenvNoCC
, fetchurl
, _7zz
}:

let
  version = "1.8.0+nightly.2763.45afbac0a5ab0d396e316ce0247fd41330c94d88";

  sources = {
    "aarch64-darwin" = {
      url = "https://zed-nightly-host.nyc3.digitaloceanspaces.com/${version}/Zed-aarch64.dmg";
      hash = "sha256-4Ip3lxOgVlDRWW8MfBfZm+65f/HV8G5/yuzje/AMu4I=";
    };
  };

  system = stdenvNoCC.hostPlatform.system;
  source = sources.${system} or (throw "zed-nightly-bin: unsupported system ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "zed-nightly-bin";
  inherit version;

  src = fetchurl { inherit (source) url hash; };

  nativeBuildInputs = [ _7zz ];
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    workdir="$(mktemp -d)"
    # APFS DMGs need two passes through 7zz: first to crack the .dmg
    # container into a raw image, then to extract the APFS volume.
    7zz x -bb0 -bd -y -o"$workdir" "$src" >/dev/null

    img="$(find "$workdir" -maxdepth 2 \
            \( -name '*.hfs' -o -name '*.apfs' -o -name '*.img' \) -print -quit)"
    if [ -n "$img" ]; then
      7zz x -bb0 -bd -y -o"$workdir/extracted" "$img" >/dev/null
      root="$workdir/extracted"
    else
      # Some 7zz builds inline the volume into the first pass.
      root="$workdir"
    fi

    app="$(find "$root" -maxdepth 4 -name '*.app' -type d -print -quit)"
    test -n "$app" || {
      echo "no .app bundle in dmg" >&2
      find "$root" -maxdepth 4 | head -50 >&2
      exit 1
    }

    mkdir -p "$out/Applications"
    cp -R "$app" "$out/Applications/"

    appname="$(basename "$app")"
    mkdir -p "$out/bin"
    ln -s "../Applications/$appname/Contents/MacOS/cli" "$out/bin/zeditor"

    runHook postInstall
  '';

  meta = {
    description = "Zed editor — prebuilt nightly channel binary";
    homepage = "https://zed.dev/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "zeditor";
  };
}
