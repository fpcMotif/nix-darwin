{ lib
, stdenvNoCC
, fetchurl
}:

let
  version = "2.13.0";

  releaseBase = "https://github.com/jdx/hk/releases/download/v${version}";

  sources = {
    aarch64-darwin = {
      asset = "hk-aarch64-apple-darwin.tar.gz";
      hash = "sha256-ZO/EQdwIWKF1kJ/WJT3dbFQNqA59G9KirQ7JwM2rPZc=";
    };
    aarch64-linux = {
      asset = "hk-aarch64-unknown-linux-musl.tar.gz";
      hash = "sha256-z/LUM6ghBKznCEojlw/wWwvzylKeAMYdogeAEEEGo90=";
    };
    x86_64-linux = {
      asset = "hk-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-PVrmLivv6V+m/H/9Y6CHbD7+NAljT71lYbi7C+eH7q4=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "hk-bin is not packaged for ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "hk-bin";
  inherit version;

  src = fetchurl {
    url = "${releaseBase}/${source.asset}";
    inherit (source) hash;
  };

  sourceRoot = ".";
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm0755 hk "$out/bin/hk"
    runHook postInstall
  '';

  meta = {
    description = "Git hook manager and linter runner configured in Pkl, prebuilt release";
    homepage = "https://hk.jdx.dev";
    changelog = "https://github.com/jdx/hk/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "hk";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
