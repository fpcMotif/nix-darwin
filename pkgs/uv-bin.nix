{ lib
, stdenvNoCC
, fetchurl
}:

let
  version = "0.13.9";

  releaseBase = "https://github.com/astral-sh/uv/releases/download/${version}";

  sources = {
    aarch64-darwin = {
      asset = "uv-aarch64-apple-darwin.tar.gz";
      hash = "sha256-WuymfyKD91I13kDQvZwKW7xfziO21Is7+fobLbCDgso=";
    };
    aarch64-linux = {
      asset = "uv-aarch64-unknown-linux-musl.tar.gz";
      hash = "sha256-N/u3xbxmz5nBKqiBlJ0hYYHiAd7ESXcsQynlZIfWEXk=";
    };
    x86_64-linux = {
      asset = "uv-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-WMz18XkrilqI0BvJEOoTGos9tKMZoXrV+tdeCEWj4nE=";
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
