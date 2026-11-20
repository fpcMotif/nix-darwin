{ lib
, stdenvNoCC
, fetchurl
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "nub";
  version = "0.9.7";

  src = fetchurl {
    url = "https://github.com/nubjs/nub/releases/download/v${finalAttrs.version}/nub-darwin-arm64.tar.gz";
    hash = "sha256-njEqwn8vgWrf0t4pmfyPQV/wbJiUnPlOEBwkzv+Bu0M=";
  };

  # Flat tarball (bin/nub, bin/nubx, runtime/); stay at the extraction root
  # and let installPhase locate the binaries so this is robust to layout
  # changes upstream.
  sourceRoot = ".";

  # Stripping would rewrite the Mach-O and break nub's code signature, so
  # leave the downloaded binaries byte-for-byte intact.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    bin="$(find . -maxdepth 2 -name nub -type f -print -quit)"
    test -n "$bin" || {
      echo "nub: no nub binary in release tarball" >&2
      ls -R >&2
      exit 1
    }
    install -Dm755 "$bin" "$out/bin/nub"

    nubx="$(find . -maxdepth 2 -name nubx -type f -print -quit)"
    if [ -n "$nubx" ]; then
      install -Dm755 "$nubx" "$out/bin/nubx"
    else
      ln -s nub "$out/bin/nubx"
    fi

    runHook postInstall
  '';

  meta = {
    description = "Bun-like DX on stock Node, written in Rust";
    homepage = "https://github.com/nubjs/nub";
    changelog = "https://github.com/nubjs/nub/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "nub";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
