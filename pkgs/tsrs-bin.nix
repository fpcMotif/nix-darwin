{ lib
, stdenvNoCC
, fetchurl
}:

let
  version = "0.18.0-ts7.1.0-dev.20260929";

  sources = {
    aarch64-darwin = {
      platform = "darwin-arm64";
      hash = "sha256-8JamXCAajatIFBenJOHMPb+vslN4hAG4jSqLAEDxDig=";
    };
    aarch64-linux = {
      platform = "linux-arm64-musl";
      hash = "sha256-STON/vEy5F602MvC+tk1qeb1d/iMgVyk4opNYuJE6yg=";
    };
    x86_64-linux = {
      platform = "linux-x64-musl";
      hash = "sha256-0ymKqxSC/2skfupyGP7emz5MCWfao3qCuDePpS9hRrU=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "tsrs-bin is not packaged for ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "tsrs-bin";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@tsrs/${source.platform}/-/${source.platform}-${version}.tgz";
    inherit (source) hash;
  };

  sourceRoot = "package";
  dontStrip = true;

  # tsrs reads the lib*.d.ts files from the directory that holds its executable.
  installPhase = ''
    runHook preInstall
    lib_dir="$out/lib/tsrs"
    install -Dm0755 tsrs "$lib_dir/tsrs"
    install -m0644 lib*.d.ts NOTICE.txt "$lib_dir/"
    mkdir -p "$out/bin"
    ln -s "$lib_dir/tsrs" "$out/bin/tsrs"
    runHook postInstall
  '';

  meta = {
    description = "Rust port of the TypeScript 7 compiler and language server, prebuilt npm release";
    homepage = "https://github.com/oxc-project/tsrs";
    license = lib.licenses.asl20;
    mainProgram = "tsrs";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
