# Build a macOS .app bundle that ships as a flat .dmg release asset with the
# .app at the dmg root. Two callers (Dropbox, Raycast) follow the same shape:
#   fetch dmg → undmg in build dir → find the .app → copy to $out/Applications.
#
# Callers pass `appName` (e.g. "Dropbox.app") and the standard derivation
# attrs. Anything not consumed here is passed through to mkDerivation.
#
# For dmgs that contain a .pkg (Google Drive) or bare .pkg installers
# (Squirrel), keep the derivation hand-rolled — the install logic diverges
# enough that a shared helper would just gain knobs.
{ stdenvNoCC, undmg }:

{ pname
, version
, src
, appName
, meta ? { }
, ...
}@args:

stdenvNoCC.mkDerivation (args // {
  inherit pname version src meta;

  nativeBuildInputs = (args.nativeBuildInputs or [ ]) ++ [ undmg ];
  sourceRoot = ".";
  phases = [ "unpackPhase" "installPhase" ];

  installPhase = ''
    runHook preInstall

    bundle="$(find . -maxdepth 3 -name '${appName}' -type d -print -quit)"
    test -n "$bundle" || (echo "${appName} not found in dmg" >&2; ls -la; exit 1)

    mkdir -p "$out/Applications"
    cp -R "$bundle" "$out/Applications/"

    runHook postInstall
  '';
})
