{ lib
, stdenvNoCC
, fetchurl
, autoPatchelfHook
}:

let
  version = "0.112.0";

  # Factory publishes per-platform binary-only npm packages. These URLs are pinned to
  # a released build and mapped by system so we install the correct native executable
  # for each platform this flake supports.
  sources = {
    "aarch64-darwin" = {
      url = "https://registry.npmjs.org/@factory/cli-darwin-arm64/-/cli-darwin-arm64-0.112.0.tgz";
      hash = "sha256-SOlbM2DsX6hM3Fo0+7kjxNQqWHNLwjb5nd3bRXSkAGY=";
    };
    "x86_64-darwin" = {
      url = "https://registry.npmjs.org/@factory/cli-darwin-x64-baseline/-/cli-darwin-x64-baseline-0.112.0.tgz";
      hash = "sha256-FAX6ttlL+nmx6aCmUa6Aublsm3bVnSZ9nmgQX/8YWys=";
    };
    "aarch64-linux" = {
      url = "https://registry.npmjs.org/@factory/cli-linux-arm64/-/cli-linux-arm64-0.112.0.tgz";
      hash = "sha256-jh7iAegh2bSUFaIXiJytpbzkFNe75eEdf503hg5itiA=";
    };
    "x86_64-linux" = {
      url = "https://registry.npmjs.org/@factory/cli-linux-x64-baseline/-/cli-linux-x64-baseline-0.112.0.tgz";
      hash = "sha256-EVMxiYCrbwDrqgg6hGms8SmkHwy4KB8VtPlTrh3xvms=";
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
