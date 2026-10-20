{ lib
, stdenvNoCC
, fetchurl
,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "pi-coding-agent";
  version = "1.3.0";

  src = fetchurl {
    url = "https://github.com/badlogic/pi-mono/releases/download/v${finalAttrs.version}/pi-darwin-arm64.tar.gz";
    hash = "sha256-H5rmHN6uBN1oyvGh6KuOybKSBi9syzJS4KnL6TtbFvE=";
  };

  sourceRoot = "pi";

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true; # don't strip a Bun-compiled standalone
  dontPatchELF = true; # macOS, but be explicit

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/pi-coding-agent $out/bin
    cp -R . $out/libexec/pi-coding-agent/
    chmod +x $out/libexec/pi-coding-agent/pi
    ln -s $out/libexec/pi-coding-agent/pi $out/bin/pi

    runHook postInstall
  '';

  meta = {
    description = "Coding-agent CLI with read/bash/edit/write tools (pi-mono)";
    homepage = "https://github.com/badlogic/pi-mono";
    changelog = "https://github.com/badlogic/pi-mono/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "pi";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
