{ lib
, stdenvNoCC
, bun
, git
, makeWrapper
}:

let
  version = (lib.importJSON ./jev-traits/package.json).version;
  hooks = ../modules/home/claude/mods/jev-traits/hooks;

  nodeModules = stdenvNoCC.mkDerivation {
    pname = "jev-traits-node-modules";
    inherit version;
    src = lib.fileset.toSource {
      root = ./jev-traits;
      fileset = lib.fileset.unions [ ./jev-traits/package.json ./jev-traits/bun.lock ];
    };
    nativeBuildInputs = [ bun ];
    impureEnvVars = lib.fetchers.proxyImpureEnvVars;
    dontConfigure = true;
    buildPhase = ''
      runHook preBuild
      export HOME=$TMPDIR
      bun install --frozen-lockfile --production --ignore-scripts --no-progress
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir $out
      cp -R node_modules $out/
      runHook postInstall
    '';
    dontFixup = true;
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-ifMSIL8d9PBbPeRZtYlMYzGNqoI6sQXbiNY8NvZQ8Mo=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "jev-traits";
  inherit version;
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ./jev-traits/package.json
      ./jev-traits/main.ts
      ./jev-traits/JevTraits.ts
      (hooks + "/check.ts")
      (hooks + "/jev.ts")
      (hooks + "/traits.ts")
    ];
  };
  nativeBuildInputs = [ bun makeWrapper ];
  dontConfigure = true;
  buildPhase = ''
    runHook preBuild
    cd pkgs/jev-traits
    ln -s ${nodeModules}/node_modules node_modules
    bun build main.ts --target bun --outfile jev-traits.js
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm444 jev-traits.js $out/libexec/jev-traits/jev-traits.js
    makeWrapper ${lib.getExe bun} $out/bin/jev-traits \
      --add-flags $out/libexec/jev-traits/jev-traits.js \
      --suffix PATH : ${lib.makeBinPath [ git ]}
    runHook postInstall
  '';

  meta = {
    description = "Check code against a repository's .agents/traits with TypeSafe Jev";
    mainProgram = "jev-traits";
    platforms = lib.platforms.darwin;
  };
}
