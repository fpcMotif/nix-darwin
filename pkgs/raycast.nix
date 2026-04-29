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
    hash = "sha256-3oAPhRK9pU/Ipq0S9jGEQDlso201n8xFvfPuOtjG5n0=";
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
