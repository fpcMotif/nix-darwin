{ lib
, stdenv
, fetchurl
, undmg
,
}:

stdenv.mkDerivation {
  pname = "dropbox";
  version = "latest";

  src = fetchurl {
    url = "https://www.dropbox.com/download?plat=mac&full=1";
    name = "Dropbox.dmg";
    hash = "sha256-pIKS73MwH9SBXg39zqevGxcHXbK0jFjz+onWhG4/E3g=";
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
