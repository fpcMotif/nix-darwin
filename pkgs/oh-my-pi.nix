{ lib
, stdenvNoCC
, fetchurl
,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "oh-my-pi";
  version = "18.12.5";

  src = fetchurl {
    url = "https://github.com/can1357/oh-my-pi/releases/download/v${finalAttrs.version}/omp-darwin-arm64";
    hash = "sha256-XlDfmHnekWXVxt9eSLtdA4c3JwATzYSeGJ2nd0+3Nos=";
  };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall

    install -Dm 755 $src $out/bin/omp

    runHook postInstall
  '';

  meta = {
    description = "AI coding agent for the terminal (oh-my-pi fork of pi-mono)";
    homepage = "https://github.com/can1357/oh-my-pi";
    changelog = "https://github.com/can1357/oh-my-pi/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "omp";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
