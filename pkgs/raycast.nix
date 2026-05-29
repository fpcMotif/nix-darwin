{ lib
, stdenv
, fetchurl
, undmg
,
}:

stdenv.mkDerivation rec {
  pname = "raycast";
  version = "1.104.19";

  src = fetchurl {
    url = "https://releases.raycast.com/releases/${version}/download?build=universal";
    name = "Raycast.dmg";
    hash = "sha256-ukU7W5VTyp8JpS9V7+EMhjrdX/lGblu/EsUGrR2i/II=";
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
