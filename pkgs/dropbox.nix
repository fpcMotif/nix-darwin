{ lib
, stdenv
, fetchurl
, undmg
,
}:

stdenv.mkDerivation rec {
  pname = "dropbox";
  version = "250.4.3245";

  src = fetchurl {
    url = "https://edge.dropboxstatic.com/dbx-releng/client/Dropbox%20${version}.dmg";
    name = "Dropbox.dmg";
    hash = "sha256-dG5GYtZiGz8f9QeYRocpINt6F3p6itI00eAUzcq+4yI=";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";
  phases = [ "unpackPhase" "installPhase" ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    cp -R "Dropbox.app" "$out/Applications/"

    runHook postInstall
  '';

  meta = {
    description = "Dropbox client";
    homepage = "https://www.dropbox.com";
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
    license = lib.licenses.unfree;
  };
}
