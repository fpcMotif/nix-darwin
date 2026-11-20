{ lib
, stdenvNoCC
, bun
, git
, makeWrapper
, src
}:

let
  inherit (lib.importJSON "${src}/traits/package.json") version;

  # --filter traits installs only the CLI workspace's dependencies; the whole
  # workspace (alchemy, the traits.sh site) is over 1 GB.
  nodeModules = stdenvNoCC.mkDerivation {
    pname = "traits-node-modules";
    inherit version src;
    nativeBuildInputs = [ bun ];
    impureEnvVars = lib.fetchers.proxyImpureEnvVars;
    dontConfigure = true;
    buildPhase = ''
      runHook preBuild
      export HOME=$TMPDIR
      bun install --frozen-lockfile --production --ignore-scripts --no-progress --filter traits
      if ls node_modules/.bun | grep -E '^(alchemy|@distilled\.cloud|cloudflare|workerd|@aws-sdk)'; then
        echo "traits-node-modules: the docs-site deploy dependencies leaked into the CLI install" >&2
        exit 1
      fi
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out/traits
      cp -R node_modules $out/
      cp -R traits/node_modules $out/traits/
      runHook postInstall
    '';
    dontFixup = true;
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-IylqArZlPSVldadPbygdAtnmy6MEXSE5F/J+gW/clU4=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "traits";
  inherit version src;
  nativeBuildInputs = [ makeWrapper ];
  dontConfigure = true;
  dontBuild = true;
  # bin.ts installs dependencies into the caller's folder, so the wrapper runs
  # main.ts against the prebuilt node_modules instead.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/libexec/traits
    cp -R traits $out/libexec/traits/traits
    ln -s ${nodeModules}/node_modules $out/libexec/traits/node_modules
    ln -s ${nodeModules}/traits/node_modules $out/libexec/traits/traits/node_modules
    makeWrapper ${lib.getExe bun} $out/bin/traits \
      --add-flags $out/libexec/traits/traits/main.ts \
      --suffix PATH : ${lib.makeBinPath [ git ]}
    runHook postInstall
  '';

  meta = {
    description = "Check code against a repository's .agents/traits with TypeSafe Jev";
    homepage = "https://github.com/fpcMotif/traits";
    license = lib.licenses.asl20;
    mainProgram = "traits";
    platforms = lib.platforms.darwin;
  };
}
