{ lib
, stdenvNoCC
, fetchzip
, fetchurl
, makeWrapper
, bash
,
}:

let
  version = "1.75.0";

  src = fetchzip {
    url = "https://github.com/tw93/Mole/archive/refs/tags/V${version}.tar.gz";
    hash = "sha256-3LmRQO+qmOSR3TKX3Wp30+XFKbcbW/vESmivFu8HN3s=";
  };

  analyzeBin = fetchurl {
    url = "https://github.com/tw93/Mole/releases/download/V${version}/analyze-darwin-arm64";
    hash = "sha256-zXev00r8TuBTY7CET7wcGTnK2EtLknC4fUnQjH6kHr8=";
  };

  statusBin = fetchurl {
    url = "https://github.com/tw93/Mole/releases/download/V${version}/status-darwin-arm64";
    hash = "sha256-IRByCTrB4EcvrR7Pz/QBkM4R6goOIyF1Zq2MO4AksFY=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "mole";
  inherit version src;

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ bash ];

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
      --prefix PATH : "${lib.makeBinPath [ bash ]}" \
      --set BASH "${bash}/bin/bash"
    makeWrapper "$share/mo"   "$out/bin/mo" \
      --prefix PATH : "${lib.makeBinPath [ bash ]}" \
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
