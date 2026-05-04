{ lib
, stdenvNoCC
, fetchurl
, undmg
,
}:

stdenvNoCC.mkDerivation rec {
  pname = "sf-symbols";
  version = "7";

  src = fetchurl {
    url = "https://devimages-cdn.apple.com/design/resources/download/SF-Symbols-${version}.dmg";
    hash = "sha256-wvIneQKZylFCIDac6DBXB3RX+8wI8OCjJi4zvKRAigI=";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    pkg="$(find . -maxdepth 3 -name 'SF Symbols*.pkg' -print -quit)"
    test -n "$pkg" || (echo "no SF Symbols pkg in dmg" >&2; ls -la; exit 1)

    /usr/sbin/pkgutil --expand-full "$pkg" expanded

    appbundle="$(find expanded -maxdepth 6 -name 'SF Symbols.app' -type d -print -quit)"
    if [ -n "$appbundle" ]; then
      mkdir -p "$out/Applications"
      cp -R "$appbundle" "$out/Applications/"
    fi

    fontsdir="$out/share/fonts/truetype"
    mkdir -p "$fontsdir"
    find expanded -name '*.otf' -exec cp {} "$fontsdir/" \; 2>/dev/null || true

    runHook postInstall
  '';

  meta = {
    description = "Apple SF Symbols app and companion fonts";
    homepage = "https://developer.apple.com/sf-symbols/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
  };
}
