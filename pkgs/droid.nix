{ lib
, stdenvNoCC
, fetchurl
, autoPatchelfHook
}:

let
  version = "0.117.0";

  # Factory publishes per-platform binary-only npm packages. These URLs are pinned to
  # a released build and mapped by system so we install the correct native executable
  # for each platform this flake supports.
  sources = {
    "aarch64-darwin" = {
      url = "https://registry.npmjs.org/@factory/cli-darwin-arm64/-/cli-darwin-arm64-${version}.tgz";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
    "x86_64-darwin" = {
      url = "https://registry.npmjs.org/@factory/cli-darwin-x64-baseline/-/cli-darwin-x64-baseline-${version}.tgz";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
    "aarch64-linux" = {
      url = "https://registry.npmjs.org/@factory/cli-linux-arm64/-/cli-linux-arm64-${version}.tgz";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
    "x86_64-linux" = {
      url = "https://registry.npmjs.org/@factory/cli-linux-x64-baseline/-/cli-linux-x64-baseline-${version}.tgz";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "Unsupported platform for martin droid package: ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "droid";
  inherit version;

  src = fetchurl {
    inherit (source) url hash;
  };

  sourceRoot = ".";

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    install -m 755 "package/bin/droid" "$out/bin/droid"

    runHook postInstall
  '';

  meta = {
    description = "Factory Droid CLI";
    homepage = "https://factory.ai";
    license = lib.licenses.unfree;
    mainProgram = "droid";
    platforms = builtins.attrNames sources;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
