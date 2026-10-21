{ lib
, stdenvNoCC
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
,
}:

let
  version = "0.164.0-alpha.8";

  sources = {
    aarch64-darwin = {
      asset = "codex-aarch64-apple-darwin";
      hash = "sha256-yj2CUbk+ZehPHtQzVhxaNvzFh5EiV9oJWihBOr/adUc=";
      host.asset = "codex-code-mode-host-aarch64-apple-darwin";
      host.hash = "sha256-GkXwlx+e3lhIr+MtAcj37ByzcnKcJogBgzupFIIQuHc=";
    };
    x86_64-darwin = {
      asset = "codex-x86_64-apple-darwin";
      hash = "sha256-woyocvEPw6XpNx05WNbIu+2MO6HtoxKvHyoJXqvXCdA=";
      host.asset = "codex-code-mode-host-x86_64-apple-darwin";
      host.hash = "sha256-RHwKQyzKL6yT2puU6nasTH6vUN0NKgWCW8cUbnMmPSc=";
    };
    aarch64-linux = {
      asset = "codex-aarch64-unknown-linux-musl";
      hash = "sha256-s8vMoI25VG8isggCPu58N76mf1qsmNQwhD6f96zNeAw=";
      host.asset = "codex-code-mode-host-aarch64-unknown-linux-musl";
      host.hash = "sha256-23mJ48cUQ2iA/X6Cbei7j5QfOxFr9CovmUF+go6kTkU=";
    };
    x86_64-linux = {
      asset = "codex-x86_64-unknown-linux-musl";
      hash = "sha256-m2PbCm6N5nh31y2rAP0TnTx8sGs9g5nOwqT9LlXrsOk=";
      host.asset = "codex-code-mode-host-x86_64-unknown-linux-musl";
      host.hash = "sha256-Z7Br0bkX9+S1hPGluhjLT7OvXiBvY0RT4vAB1xReh6s=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "codex is not packaged for ${stdenvNoCC.hostPlatform.system}");
  release = asset: hash: fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/${asset}.tar.gz";
    inherit hash;
  };
  codeModeHost = release source.host.asset source.host.hash;
in
stdenvNoCC.mkDerivation {
  pname = "codex";
  inherit version;

  src = release source.asset source.hash;

  nativeBuildInputs = [ makeWrapper ];
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    tar -xzf "$src"
    install -Dm0755 "${source.asset}" "$out/bin/codex"
    tar -xzf "${codeModeHost}"
    install -Dm0755 "${source.host.asset}" "$out/bin/codex-code-mode-host"

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
