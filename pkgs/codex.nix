{ lib
, stdenvNoCC
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
,
}:

let
  version = "0.150.0-alpha.11";

  sources = {
    aarch64-darwin = {
      asset = "codex-aarch64-apple-darwin";
      hash = "sha256-aQP7XfD0Rzw6tFMK65IYuFJPbJgSeCryHTR7onJVylI=";
    };
    x86_64-darwin = {
      asset = "codex-x86_64-apple-darwin";
      hash = "sha256-7E4MqJSbrUVKTrBpATsk5dfrFa81ayNpahm+JTi0MYE=";
    };
    aarch64-linux = {
      asset = "codex-aarch64-unknown-linux-musl";
      hash = "sha256-Pf9SAulERAEJNL7Dr0d0SfhuUzi9FX9nEhkeeRNkIn4=";
    };
    x86_64-linux = {
      asset = "codex-x86_64-unknown-linux-musl";
      hash = "sha256-khwJ5bm6teCnS+4O1wEfU/Haz8M9QXSu8ezR9avjuFw=";
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
