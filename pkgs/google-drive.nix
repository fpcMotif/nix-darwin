{
  lib,
  stdenv,
  fetchurl,
  undmg,
}:

stdenv.mkDerivation {
  pname = "google-drive";
  version = "latest";

  src = fetchurl {
    url = "https://dl.google.com/drive-file-stream/GoogleDrive.dmg";
    hash = "sha256-zrFs+5BWqjSzvxrQFcR1NlGes8Mhp6OLdx6sjYFuZGY=";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";
  phases = [ "unpackPhase" "installPhase" ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    /usr/sbin/pkgutil --expand-full "GoogleDrive.pkg" expanded
    cp -R "expanded/GoogleDrive_arm64.pkg/Payload/Google Drive.app" "$out/Applications/"

    runHook postInstall
  '';

  meta = {
    description = "Google Drive client";
    homepage = "https://www.google.com/drive/";
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
    license = lib.licenses.unfree;
  };
}
