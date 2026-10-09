{ lib
, stdenvNoCC
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
,
}:

let
  version = "0.163.0-alpha.2";

  sources = {
    aarch64-darwin = {
      asset = "codex-aarch64-apple-darwin";
      hash = "sha256-xwxX+JDd1ACuR4fYPvQgFJvOKklydolZI1/UdryN0wo=";
      host.asset = "codex-code-mode-host-aarch64-apple-darwin";
      host.hash = "sha256-geVJ8HZ07UsIAKJrP8nJY9PGcfMy/pSCxYNWqGqw9rA=";
    };
    x86_64-darwin = {
      asset = "codex-x86_64-apple-darwin";
      hash = "sha256-dqlxCx+3xtfUyjidzX+CO0QKGQRikL+ZM9o8PyQ4sk4=";
      host.asset = "codex-code-mode-host-x86_64-apple-darwin";
      host.hash = "sha256-d9MSspGOasQYso5qwNc3/7RzaomKdbPB1lx5SXTHCK8=";
    };
    aarch64-linux = {
      asset = "codex-aarch64-unknown-linux-musl";
      hash = "sha256-NNuGC14WreQQDNeGNzmViziqOOjld/Em0j5AIM9s/g8=";
      host.asset = "codex-code-mode-host-aarch64-unknown-linux-musl";
      host.hash = "sha256-jM0BGDS/gGtUPmny3CnCq7vGJQsPcG6dteTl1SlfTPM=";
    };
    x86_64-linux = {
      asset = "codex-x86_64-unknown-linux-musl";
      hash = "sha256-q5gz/jVeeCSJtouzPv/UE6bSzh4Im/RkcsNqTQprrwc=";
      host.asset = "codex-code-mode-host-x86_64-unknown-linux-musl";
      host.hash = "sha256-MgsYdQNo1eBJW04pW3Ym7eHmKcG18ahocw9cW6i2ID8=";
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
