{ lib
, stdenv
, fetchurl
, undmg
,
}:

stdenv.mkDerivation rec {
  pname = "dropbox";
  version = "252.4.3485";

  src = fetchurl {
    url = "https://edge.dropboxstatic.com/dbx-releng/client/Dropbox%20${version}.dmg";
    name = "Dropbox.dmg";
    hash = "sha256-DuAU6+w1ir2pEd5I5HPJIFTFSRN9edQ4cGZL1S63XYc=";
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
