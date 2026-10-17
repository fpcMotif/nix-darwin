{ lib
, stdenvNoCC
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
,
}:

let
  version = "0.164.0-alpha.3";

  sources = {
    aarch64-darwin = {
      asset = "codex-aarch64-apple-darwin";
      hash = "sha256-ECYUzzIogWz/0tu4J8uCCDyr8v/DWUgByfmd5jAliv4=";
      host.asset = "codex-code-mode-host-aarch64-apple-darwin";
      host.hash = "sha256-x/JOAZk+SoiTBkb4zR7JwwotaY6p1ftyYHAaKJxVZgE=";
    };
    x86_64-darwin = {
      asset = "codex-x86_64-apple-darwin";
      hash = "sha256-mIKpQiAXbsJHBffD/J/2vEEy/GcFR1IbE2rSBHOdenI=";
      host.asset = "codex-code-mode-host-x86_64-apple-darwin";
      host.hash = "sha256-CjtX/UoxCiWUoqtaSHej3m91rTj1SRRv0qLPKQinyIU=";
    };
    aarch64-linux = {
      asset = "codex-aarch64-unknown-linux-musl";
      hash = "sha256-BI8JMoSKQfTQ3f733Ba4K2PqIzIKX5t9Mo33ZIH1TME=";
      host.asset = "codex-code-mode-host-aarch64-unknown-linux-musl";
      host.hash = "sha256-SWlWlN9bqdhiHrq8SXPeRhg10barcrJxeK0yvDBNKk8=";
    };
    x86_64-linux = {
      asset = "codex-x86_64-unknown-linux-musl";
      hash = "sha256-5HaZzXGig7ThsujIpAYrsC7P1RlSw6AqcjZwtECRO6I=";
      host.asset = "codex-code-mode-host-x86_64-unknown-linux-musl";
      host.hash = "sha256-SbYu58omYfpTeddIW974KNPjtJQjivHUH41ZyBggT+g=";
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
