{
  lib,
  stdenv,
  fetchurl,
  undmg,
}:

stdenv.mkDerivation {
  pname = "google-drive";
  # Google does not publish versioned .dmg URLs; this label tracks the
  # current upstream release for review-time visibility, but the URL
  # itself still resolves to "latest". Bumps stay manual — see
  # ARCHITECTURE.md §"Package ownership".
  version = "124.0";

  src = fetchurl {
    url = "https://dl.google.com/drive-file-stream/GoogleDrive.dmg";
    hash = "sha256-sq26uY6KME65Xjof9kuHABD8RFkXtgD0LIBEeGTgFig=";
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
