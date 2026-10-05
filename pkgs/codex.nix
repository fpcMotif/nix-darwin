{ lib
, stdenvNoCC
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
,
}:

let
  version = "0.162.0-alpha.16";

  sources = {
    aarch64-darwin = {
      asset = "codex-aarch64-apple-darwin";
      hash = "sha256-PBCbWPnIQa4QwnVvih0FOlLYr3UP0wJ/UAyvTL7yMxU=";
      host.asset = "codex-code-mode-host-aarch64-apple-darwin";
      host.hash = "sha256-e53GGPetWirDUVCa+K1sG+sF1lHcI3bGLHEoIpftGRo=";
    };
    x86_64-darwin = {
      asset = "codex-x86_64-apple-darwin";
      hash = "sha256-2FsrSmg79DSN+5rzTPbKoZNkwMHDDgCXeqwGcfr+d28=";
      host.asset = "codex-code-mode-host-x86_64-apple-darwin";
      host.hash = "sha256-krIpTf2PEZZAinJRHLqPTlaLr5vt9HEkhomXlBpc/xw=";
    };
    aarch64-linux = {
      asset = "codex-aarch64-unknown-linux-musl";
      hash = "sha256-5t4x6g0wmgS/7A2X140/aNnF/FlkcKKVfveDajoyNCM=";
      host.asset = "codex-code-mode-host-aarch64-unknown-linux-musl";
      host.hash = "sha256-I8Za++UNzOYCg19i9tzsiYxJK/bMWTYQDxTZPvCCyXM=";
    };
    x86_64-linux = {
      asset = "codex-x86_64-unknown-linux-musl";
      hash = "sha256-65Fo4FHw6BGDxMM7EiuphjuHqtcsF23nM+zD1Uxa5T4=";
      host.asset = "codex-code-mode-host-x86_64-unknown-linux-musl";
      host.hash = "sha256-fsN/1BMAxhY04aWKEk5neK1kJrS9OhcNhqeYe3N4TlI=";
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
