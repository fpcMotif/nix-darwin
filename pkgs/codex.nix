{ lib
, stdenvNoCC
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
,
}:

let
  version = "0.174.0-alpha.9";

  sources = {
    aarch64-darwin = {
      asset = "codex-aarch64-apple-darwin";
      hash = "sha256-0jV9vKPWupRKZFHT2Piyh1M+ru8jn2BP4YQJKHvIpZc=";
      host.asset = "codex-code-mode-host-aarch64-apple-darwin";
      host.hash = "sha256-RpRDafivqs4XmqLXuiPAgHx7Sk7h1Hc++Kj/UirUQt4=";
    };
    x86_64-darwin = {
      asset = "codex-x86_64-apple-darwin";
      hash = "sha256-TJEBmIGMe7taGvo3O8oCeq7Hq/b3UJqU/JB43LxNTs0=";
      host.asset = "codex-code-mode-host-x86_64-apple-darwin";
      host.hash = "sha256-bgT2YUAwxHi8PGInds+D6OK1ZhFjB0zSV0uGzVTgLUY=";
    };
    aarch64-linux = {
      asset = "codex-aarch64-unknown-linux-musl";
      hash = "sha256-atTBXeXpyLeJpLGX/cVfvlxxw+DBdvS7A7jo3u8IhMQ=";
      host.asset = "codex-code-mode-host-aarch64-unknown-linux-musl";
      host.hash = "sha256-IoqZgwQNi9B4xMs68yWqVf50DNL40fz0tMYkVurEJv8=";
    };
    x86_64-linux = {
      asset = "codex-x86_64-unknown-linux-musl";
      hash = "sha256-HsZFjlDz6izszBp5mDLdY3wLORoGcS3IVCVbD4hvh6k=";
      host.asset = "codex-code-mode-host-x86_64-unknown-linux-musl";
      host.hash = "sha256-X03Kkf/Q8I1Ji3tM7zKrCyd/0eE9v0qiX5vrxGZPL84=";
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
