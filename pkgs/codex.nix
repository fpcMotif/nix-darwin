{ lib
, stdenvNoCC
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
,
}:

let
  version = "0.156.0-alpha.14";

  sources = {
    aarch64-darwin = {
      asset = "codex-aarch64-apple-darwin";
      hash = "sha256-1BCvhl7EmR3aldFXDMkb8HWmjAbTbvZ6Y2TM7414vbI=";
    };
    x86_64-darwin = {
      asset = "codex-x86_64-apple-darwin";
      hash = "sha256-KcYm6NRC+m3OoR5H+1XQwsPvrM4z6jmtFIAoppeOe78=";
    };
    aarch64-linux = {
      asset = "codex-aarch64-unknown-linux-musl";
      hash = "sha256-6qQuQwYoUi/c3h4+Vp5lKFPREPmSic/DmiGqEc5PtVA=";
    };
    x86_64-linux = {
      asset = "codex-x86_64-unknown-linux-musl";
      hash = "sha256-iUAiBzruTg7g4AUIad/WfuYzN6V89+Mbd06oBbie9kc=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "codex is not packaged for ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "codex";
  inherit version;

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/${source.asset}.tar.gz";
    inherit (source) hash;
  };

  nativeBuildInputs = [ makeWrapper ];
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    tar -xzf "$src"
    install -Dm0755 "${source.asset}" "$out/bin/codex"

    wrapProgram "$out/bin/codex" --prefix PATH : ${
      lib.makeBinPath ([ ripgrep ] ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ bubblewrap ])
    }

    runHook postInstall
  '';

  meta = {
    description = "Lightweight coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    changelog = "https://github.com/openai/codex/releases/tag/rust-v${version}";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames sources;
  };
}
