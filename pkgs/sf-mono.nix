{ lib
, stdenvNoCC
, fetchurl
, undmg
,
}:

stdenvNoCC.mkDerivation {
  pname = "sf-mono";
  version = "2025-04";

  src = fetchurl {
    url = "https://devimages-cdn.apple.com/design/resources/download/SF-Mono.dmg";
    hash = "sha256-bUoLeOOqzQb5E/ZCzq0cfbSvNO1IhW1xcaLgtV2aeUU=";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    pkg="$(find . -maxdepth 3 -name 'SF Mono*.pkg' -print -quit)"
    test -n "$pkg" || (echo "no SF Mono pkg in dmg" >&2; ls -la; exit 1)

    /usr/sbin/pkgutil --expand-full "$pkg" expanded

    fontsdir="$out/share/fonts/truetype"
    mkdir -p "$fontsdir"

    find expanded -name '*.otf' -exec cp {} "$fontsdir/" \;
    find expanded -name '*.ttf' -exec cp {} "$fontsdir/" \;

    runHook postInstall
  '';

  meta = {
    description = "Apple SF Mono font family";
    homepage = "https://developer.apple.com/fonts/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
  };
}
