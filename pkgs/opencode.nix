{ lib
, stdenvNoCC
, fetchzip
, fetchurl
, autoPatchelfHook
, unzip
, gnutar
,
}:

let
  version = "1.19.3";

  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/sst/opencode/releases/download/v${version}/opencode-darwin-arm64.zip";
      hash = "sha256-wtD+zSes9uCL4CwfXThGFNB0lVh3ZrzEpr/zlxdJu2Q=";
      isZip = true;
    };
    "x86_64-linux" = {
      url = "https://github.com/sst/opencode/releases/download/v${version}/opencode-linux-x64.tar.gz";
      hash = "sha256-E6j7KXgwIHG4b51+ANqciJX5zYRpeDecO9xqUzNTbJs=";
      isZip = false;
    };
    "aarch64-linux" = {
      url = "https://github.com/sst/opencode/releases/download/v${version}/opencode-linux-arm64.tar.gz";
      hash = "sha256-eQCBimqYiB7butq0t1JZQO/zuXUAQMIASB+fVsrO5AU=";
      isZip = false;
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "opencode: unsupported platform ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "opencode";
  inherit version;

  src = fetchurl {
    inherit (source) url hash;
  };

  dontUnpack = true;

  nativeBuildInputs = [
    (if source.isZip then unzip else gnutar)
  ] ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    cd "$out/bin"
    ${if source.isZip then "unzip -j" else "tar -xzf"} "$src"
    chmod 0755 opencode
    test -x opencode || (echo "opencode binary missing after extract" >&2; ls -la; exit 1)

    runHook postInstall
  '';

  meta = {
    description = "opencode — terminal-based AI coding agent (sst/opencode)";
    homepage = "https://opencode.ai";
    license = lib.licenses.mit;
    mainProgram = "opencode";
    platforms = builtins.attrNames sources;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
