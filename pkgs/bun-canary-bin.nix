{ lib
, stdenvNoCC
, fetchurl
}:

let
  version = "1.4.4-canary.20261029.1";

  sources = {
    "aarch64-darwin" = {
      url = "https://registry.npmjs.org/@oven/bun-darwin-aarch64/-/bun-darwin-aarch64-${version}.tgz";
      hash = "sha256-VI/del21Ow8n1l9wKJN2cUEO3/CBFdslmCEKbnaE1Wg=";
    };
  };

  system = stdenvNoCC.hostPlatform.system;
  source = sources.${system} or (throw "bun-canary-bin: unsupported system ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "bun-canary-bin";
  inherit version;

  src = fetchurl { inherit (source) url hash; };

  # Stripping rewrites the Mach-O and invalidates bun's code signature.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/bun "$out/bin/bun"
    ln -s bun "$out/bin/bunx"
    runHook postInstall
  '';

  meta = {
    description = "Bun — prebuilt canary channel binary";
    homepage = "https://bun.sh/";
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "bun";
  };
}
