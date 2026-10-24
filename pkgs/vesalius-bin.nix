{ lib
, stdenvNoCC
, fetchurl
}:

stdenvNoCC.mkDerivation rec {
  pname = "vesalius-bin";
  version = "2.1.0";

  src = fetchurl {
    url = "https://github.com/haplollc/Vesalius/releases/download/v${version}/vesalius-${version}-macos-arm64.tar.gz";
    hash = "sha256-M3hyxVw7otyyoQ8eBq3nq84bMqmBhuWVPC2fjWVEE6k=";
  };

  sourceRoot = ".";
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm0755 vesalius "$out/bin/vesalius"
    runHook postInstall
  '';

  meta = {
    description = "On-device code graph with an MCP server for Claude Code, prebuilt release";
    homepage = "https://github.com/haplollc/Vesalius";
    changelog = "https://github.com/haplollc/Vesalius/releases/tag/v${version}";
    license = lib.licenses.unfree;
    mainProgram = "vesalius";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
