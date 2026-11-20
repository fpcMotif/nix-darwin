{ lib
, stdenvNoCC
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
,
}:

let
  version = "0.166.0";

  sources = {
    aarch64-darwin = {
      asset = "codex-aarch64-apple-darwin";
      hash = "sha256-xIgkRi/FdoHq+wkl2XsRtYkBBHVhOQT1cLQv6lPiQNU=";
      host.asset = "codex-code-mode-host-aarch64-apple-darwin";
      host.hash = "sha256-er1Q/l8DNJWntpPEX7gtxXCToY8cS6PoBDV33kbFx8U=";
    };
    x86_64-darwin = {
      asset = "codex-x86_64-apple-darwin";
      hash = "sha256-2ww4cTw2GZsS58jRYpOGw1pM6PmeHJznLxclp032e1c=";
      host.asset = "codex-code-mode-host-x86_64-apple-darwin";
      host.hash = "sha256-s1x3XV5fjWDQXg3nFU5bu/MgttDiijI31CzIp0LMr2U=";
    };
    aarch64-linux = {
      asset = "codex-aarch64-unknown-linux-musl";
      hash = "sha256-lOtwdgXsJkay4Ft+33xOezzPArFiN8NK6b64z7f4EKk=";
      host.asset = "codex-code-mode-host-aarch64-unknown-linux-musl";
      host.hash = "sha256-rJjR+HjjU6FsunEf1Hv+8vbIFBCb3YGe4ra21qGXAec=";
    };
    x86_64-linux = {
      asset = "codex-x86_64-unknown-linux-musl";
      hash = "sha256-oL9XLS+T8FbGcSpto0jpYHjchPOIX9e+Z4B+84nLOXg=";
      host.asset = "codex-code-mode-host-x86_64-unknown-linux-musl";
      host.hash = "sha256-dYgzT9R7xAA9lwtw39TR5FeEkbHpuqcpdqTC1+l1kNo=";
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
