{ lib
, stdenv
, fetchurl
, undmg
,
}:

stdenv.mkDerivation {
  pname = "raycast";
  version = "latest";

  src = fetchurl {
    url = "https://api.raycast.app/v2/download";
    name = "Raycast.dmg";
    hash = "sha256-27kvr1ilsjmYYiZnffJO8U5GFwpM82hc/DoBcgE+Lrc=";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";
  phases = [ "unpackPhase" "installPhase" ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    cp -R "Raycast.app" "$out/Applications/"

    runHook postInstall
  '';

  meta = {
    description = "Raycast launcher";
    homepage = "https://www.raycast.com";
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
    license = lib.licenses.unfree;
  };
}
