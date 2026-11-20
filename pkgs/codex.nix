{ lib
, stdenvNoCC
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
,
}:

let
  version = "0.171.0-alpha.5";

  sources = {
    aarch64-darwin = {
      asset = "codex-aarch64-apple-darwin";
      hash = "sha256-GTKcJV05HR8EnsMy7TCUAIn5z46iSHbnhX9ScpV6RyE=";
      host.asset = "codex-code-mode-host-aarch64-apple-darwin";
      host.hash = "sha256-mbzxONGa2pT+qnJJcMzU7Ui2ScLFuBoxcDG2FVr8QO0=";
    };
    x86_64-darwin = {
      asset = "codex-x86_64-apple-darwin";
      hash = "sha256-G8MYtQPeWPA2qHM8RJDztGHU9W3nEfBDrYf8iJtHXgg=";
      host.asset = "codex-code-mode-host-x86_64-apple-darwin";
      host.hash = "sha256-PuvLMy+GnZIG1LIxcuxIsKHFRdT42qUHAzRVV0eb+cQ=";
    };
    aarch64-linux = {
      asset = "codex-aarch64-unknown-linux-musl";
      hash = "sha256-hVjqqkshT9nziTiQJ6TTdVgee5MxGMkUxlFdTbA2LFc=";
      host.asset = "codex-code-mode-host-aarch64-unknown-linux-musl";
      host.hash = "sha256-gInBIKNYZk+W5irYwFOyzrCdsMLm1vV3H1v2pDIpV2I=";
    };
    x86_64-linux = {
      asset = "codex-x86_64-unknown-linux-musl";
      hash = "sha256-wIlzMtE5WXnrKtgtl1nvoDEKp+RMlE0PDcp/q6JdEN0=";
      host.asset = "codex-code-mode-host-x86_64-unknown-linux-musl";
      host.hash = "sha256-hPaSOCSzmoM8IyyAHR+lV4qAIF0tTL85MrJ3Cu9OSU4=";
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
