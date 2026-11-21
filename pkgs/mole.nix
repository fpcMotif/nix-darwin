{ lib
, stdenvNoCC
, fetchzip
, fetchurl
, makeWrapper
, bash
,
}:

let
  version = "1.73.0";

  src = fetchzip {
    url = "https://github.com/tw93/Mole/archive/refs/tags/V${version}.tar.gz";
    hash = "sha256-3TJL45ggnN8DWv+uOhSUdbrRp3QLm8laT84lBT+rt50=";
  };

  analyzeBin = fetchurl {
    url = "https://github.com/tw93/Mole/releases/download/V${version}/analyze-darwin-arm64";
    hash = "sha256-2vFblhdbAL7/DrQYkL8QjBj9xLpGFIXPtVIrNP9Pa0w=";
  };

  statusBin = fetchurl {
    url = "https://github.com/tw93/Mole/releases/download/V${version}/status-darwin-arm64";
    hash = "sha256-RMq9SL2cKvV6iNPOArvFyRsqYgnAZMa0wB1poaE8ar8=";
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
