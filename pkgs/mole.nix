# tw93/Mole — deep-clean / disk-analyzer / live-status TUI for macOS.
#
# Mole is a bash-driven CLI that sources `lib/core/*.sh` from $SCRIPT_DIR and
# `exec`s sibling subcommand scripts under `bin/`. Two of those subcommands
# (`analyze`, `status`) shell out to bundled Go binaries at `bin/analyze-go`
# and `bin/status-go`.
#
# To stay 100% offline-evaluatable and avoid Mole's runtime self-update
# (which writes into $SCRIPT_DIR), we ship the upstream tag tarball plus the
# matching prebuilt arm64 Go binaries from the same release. The whole tree
# lands in $out/share/mole; tiny wrappers in $out/bin re-exec into it so
# $BASH_SOURCE / $SCRIPT_DIR resolve back to the right place.
{ lib
, stdenvNoCC
, fetchzip
, fetchurl
, makeWrapper
, bash
,
}:

let
  version = "1.40.0";

  src = fetchzip {
    url = "https://github.com/tw93/Mole/archive/refs/tags/V${version}.tar.gz";
    hash = "sha256-N7Gd4z+sCenuS1f4ZqRgKNzBBv3J9D3nrk2QmVifIOY=";
  };

  analyzeBin = fetchurl {
    url = "https://github.com/tw93/Mole/releases/download/V${version}/analyze-darwin-arm64";
    hash = "sha256-fgpqh2SDQL/PN7StspNNDrK1kfjGQqTRrysSlwwsKO0=";
  };

  statusBin = fetchurl {
    url = "https://github.com/tw93/Mole/releases/download/V${version}/status-darwin-arm64";
    hash = "sha256-6rhqI5corGYIszgm5jpSheJMdcHTfLGG2N10N7rPe1Q=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "mole";
  inherit version src;

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    share="$out/share/mole"
    mkdir -p "$share/bin" "$out/bin"

    cp -R . "$share/"
    chmod +x "$share/mole" "$share/mo"
    chmod -R u+w "$share"

    install -m 0755 "${analyzeBin}" "$share/bin/analyze-go"
    install -m 0755 "${statusBin}"  "$share/bin/status-go"

    # Wrappers exec into share/, so $BASH_SOURCE inside the script resolves to
    # share/mole and $SCRIPT_DIR finds bin/, lib/, scripts/ as siblings.
    makeWrapper "$share/mole" "$out/bin/mole" \
      --set BASH "${bash}/bin/bash"
    makeWrapper "$share/mo"   "$out/bin/mo" \
      --set BASH "${bash}/bin/bash"

    runHook postInstall
  '';

  meta = {
    description = "Deep clean and optimize your Mac (CleanMyMac alternative)";
    homepage = "https://github.com/tw93/Mole";
    changelog = "https://github.com/tw93/Mole/releases/tag/V${version}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" ];
    mainProgram = "mo";
  };
}
