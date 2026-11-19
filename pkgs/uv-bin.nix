{ lib
, stdenvNoCC
, fetchurl
}:

let
  version = "0.13.8";

  releaseBase = "https://github.com/astral-sh/uv/releases/download/${version}";

  sources = {
    aarch64-darwin = {
      asset = "uv-aarch64-apple-darwin.tar.gz";
      hash = "sha256-a3ECimuQTyrjNA71LllVEt6AfQbAog6u8vaSWBskZVg=";
    };
    aarch64-linux = {
      asset = "uv-aarch64-unknown-linux-musl.tar.gz";
      hash = "sha256-DG+Fk/zx6t/GDmY7aFxAgmdVnXxdYcaJu7nzp+NpujI=";
    };
    x86_64-linux = {
      asset = "uv-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-Yfsm2rxPDPHQUPxsZ9QOQ+T64plK8h68HgULIzvyte0=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "uv-bin is not packaged for ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "uv-bin";
  inherit version;

  src = fetchurl {
    url = "${releaseBase}/${source.asset}";
    inherit (source) hash;
  };

  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm0755 uv "$out/bin/uv"
    install -Dm0755 uvx "$out/bin/uvx"
    runHook postInstall
  '';

  meta = {
    description = "Python package and project manager, official prebuilt release";
    homepage = "https://docs.astral.sh/uv/";
    changelog = "https://github.com/astral-sh/uv/releases/tag/${version}";
    license = with lib.licenses; [ asl20 mit ];
    mainProgram = "uv";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
