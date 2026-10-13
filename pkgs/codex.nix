{ lib
, stdenvNoCC
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
,
}:

let
  version = "0.163.0-alpha.11";

  sources = {
    aarch64-darwin = {
      asset = "codex-aarch64-apple-darwin";
      hash = "sha256-TOs31re1kpkl5MNq6ukS8dBApDIDaWEp/Gs//gnLRSo=";
      host.asset = "codex-code-mode-host-aarch64-apple-darwin";
      host.hash = "sha256-5PGkkrOZv6UCeShRwfPik+4UAevFavE+72e9Umzuss0=";
    };
    x86_64-darwin = {
      asset = "codex-x86_64-apple-darwin";
      hash = "sha256-kL5HPryMZGP62QS+9zduUlS5rW+efNp2fYESn0TmL04=";
      host.asset = "codex-code-mode-host-x86_64-apple-darwin";
      host.hash = "sha256-LaAE9Ccks5AN0mhyF/z7Iy6+E8FBhvewhMgBfQaBo8k=";
    };
    aarch64-linux = {
      asset = "codex-aarch64-unknown-linux-musl";
      hash = "sha256-pxQ37BX63EkubHw7gEisjXQp0DgTgfKVTgyIzwaaP4Q=";
      host.asset = "codex-code-mode-host-aarch64-unknown-linux-musl";
      host.hash = "sha256-ZREdkgBkWXWfe9XWq++gykUf5L1OeEhWZ1CDwAs1FbU=";
    };
    x86_64-linux = {
      asset = "codex-x86_64-unknown-linux-musl";
      hash = "sha256-T3cR5pY6Mf+Ah0Q7rVhEY/G70tD05zQM26bGcgmgn3k=";
      host.asset = "codex-code-mode-host-x86_64-unknown-linux-musl";
      host.hash = "sha256-HKwaEatslKeFOLVB8wipiiXO5v5vuj37NdpZhxE7yg4=";
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
