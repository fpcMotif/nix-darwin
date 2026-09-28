{ lib
, stdenvNoCC
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
,
}:

let
  version = "0.162.0-alpha.9";

  sources = {
    aarch64-darwin = {
      asset = "codex-aarch64-apple-darwin";
      hash = "sha256-WWyR3kRWD3rcWyWMSlFAR0hDKLbfADlB2wVGV2bTewQ=";
      host.asset = "codex-code-mode-host-aarch64-apple-darwin";
      host.hash = "sha256-r9osL4mMmz+pH0iecLN0V7OhdWF4ZysjEvX3R48mhXg=";
    };
    x86_64-darwin = {
      asset = "codex-x86_64-apple-darwin";
      hash = "sha256-H8x+798iykw80JHW7Ve4cUxv4DaRtAKLlQIwnmab5sg=";
      host.asset = "codex-code-mode-host-x86_64-apple-darwin";
      host.hash = "sha256-rFPFALkZc20OJJXAYoPUpzY11/b8/X7C2F4oXC8oeto=";
    };
    aarch64-linux = {
      asset = "codex-aarch64-unknown-linux-musl";
      hash = "sha256-kA1yk9YmcXunAfPd3Mj9NSYopxwWy42HIQdLkt0LEeY=";
      host.asset = "codex-code-mode-host-aarch64-unknown-linux-musl";
      host.hash = "sha256-9II+oBAQv9IxxkJFFZW07eVS18eZNRm/4Fl5xYOynEE=";
    };
    x86_64-linux = {
      asset = "codex-x86_64-unknown-linux-musl";
      hash = "sha256-wJPePSYDK9vzoNvlz5tua8HcBB7iSVB67M4OhjfVoZc=";
      host.asset = "codex-code-mode-host-x86_64-unknown-linux-musl";
      host.hash = "sha256-ubvbi723cTylTTGBPS+f9g16XQ1fdp3E8AttiHCKaFQ=";
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
