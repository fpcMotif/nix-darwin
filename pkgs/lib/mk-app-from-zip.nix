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
