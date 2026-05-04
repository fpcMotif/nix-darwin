{ lib
, stdenvNoCC
, fetchurl
,
}:

stdenvNoCC.mkDerivation rec {
  pname = "squirrel";
  version = "1.1.2";

  src = fetchurl {
    url = "https://github.com/rime/squirrel/releases/download/${version}/Squirrel-${version}.pkg";
    hash = "sha256-YUdGATISk3Yj1burmQHpxD0eyTeqMjB9a2CSoF4wgoc=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    /usr/sbin/pkgutil --expand-full "$src" expanded

    mkdir -p "$out/Library/Input Methods" "$out/Applications"
    cp -R "expanded/Payload/Squirrel.app" "$out/Library/Input Methods/"
    ln -s "$out/Library/Input Methods/Squirrel.app" "$out/Applications/Squirrel.app"

    runHook postInstall
  '';

  meta = {
    description = "Squirrel, the Rime input method frontend for macOS (鼠须管)";
    homepage = "https://rime.im/";
    changelog = "https://github.com/rime/squirrel/releases/tag/${version}";
    license = lib.licenses.gpl3Plus;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
  };
}
