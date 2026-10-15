{ lib
, stdenvNoCC
, fetchurl
}:

let
  version = "0.2.2";

  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/tjarvstrand/dojjo/releases/download/v${version}/djo-macos-arm64";
      hash = "sha256-zNMpIwtiJn5Y+P21mPyhIx5lwNlhDZugH+O/v4dwFZg=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "dojjo-bin: unsupported platform ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "dojjo-bin";
  inherit version;

  src = fetchurl { inherit (source) url hash; };

  dontUnpack = true;
  # Stripping cuts the Dart AOT snapshot appended to the Mach-O.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm0755 "$src" "$out/bin/djo"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    [ "$("$out/bin/djo" --version)" = "${version}" ]
    runHook postInstallCheck
  '';

  meta = {
    description = "dojjo — Worktrunk-style workspace manager for jj, prebuilt release";
    homepage = "https://github.com/tjarvstrand/dojjo";
    changelog = "https://github.com/tjarvstrand/dojjo/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "djo";
    platforms = builtins.attrNames sources;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
