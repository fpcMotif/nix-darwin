{
  lib,
  stdenv,
  fetchurl,
  undmg,
}:

stdenv.mkDerivation {
  pname = "dropbox";
  version = "latest";

  src = fetchurl {
    url = "https://www.dropbox.com/download?plat=mac&full=1";
    name = "Dropbox.dmg";
    hash = "sha256-i6tOrY1MZBcK018q1YlXIf3CagcI9zpGl6wJjYZ7ha4=";
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
