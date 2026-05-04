# Build a macOS .app bundle that ships as a flat .zip release asset.
# Two callers (BetterMouse, Hammerspoon) follow the same shape:
#   fetch zip → unzip into a tempdir → find the .app → copy to $out/Applications.
#
# Callers pass `appName` (e.g. "BetterMouse.app") and the standard derivation
# attrs. Anything not consumed here is passed through to mkDerivation.
{ stdenvNoCC, unzip }:

{ pname
, version
, src
, appName
, meta ? { }
, ...
}@args:

stdenvNoCC.mkDerivation (args // {
  inherit pname version src meta;

  nativeBuildInputs = (args.nativeBuildInputs or [ ]) ++ [ unzip ];
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    workdir="$(mktemp -d)"
    unzip -q "$src" -d "$workdir"

    bundle="$(find "$workdir" -maxdepth 3 -name '${appName}' -type d -print -quit)"
    test -n "$bundle" || (echo "${appName} not found in zip" >&2; ls -la "$workdir"; exit 1)

    mkdir -p "$out/Applications"
    cp -R "$bundle" "$out/Applications/"

    runHook postInstall
  '';
})
