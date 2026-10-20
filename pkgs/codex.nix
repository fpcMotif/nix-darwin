{ lib
, stdenvNoCC
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
,
}:

let
  version = "0.164.0-alpha.6";

  sources = {
    aarch64-darwin = {
      asset = "codex-aarch64-apple-darwin";
      hash = "sha256-h9oypUtZMl+9dsmAx9HBt4Pq7k2G+zCKUxPoKP3X1LY=";
      host.asset = "codex-code-mode-host-aarch64-apple-darwin";
      host.hash = "sha256-uM7vrEEWIU+NyMiaL4AtVQ2agOGxRYx1UdsjnOJn6bA=";
    };
    x86_64-darwin = {
      asset = "codex-x86_64-apple-darwin";
      hash = "sha256-Q60yGKW/2TcPSz+5iA0c/Fe7caNscmQaP9v1Lwb7Dsw=";
      host.asset = "codex-code-mode-host-x86_64-apple-darwin";
      host.hash = "sha256-ZGbab+sgAdHrALhjiW29jEpWq9DLO3tLDn2Evv8hgJc=";
    };
    aarch64-linux = {
      asset = "codex-aarch64-unknown-linux-musl";
      hash = "sha256-bvgYmFXYiq9PUThOuSXwAesY5GKN6xda7gXcvhqGkYk=";
      host.asset = "codex-code-mode-host-aarch64-unknown-linux-musl";
      host.hash = "sha256-zKcihSemclV4bZ2LmiBN5eISxjQSCqKq4NT3q83kuT0=";
    };
    x86_64-linux = {
      asset = "codex-x86_64-unknown-linux-musl";
      hash = "sha256-OJuww77Dl+sy5Xf0QL3HwP453WADBj9Kky5eae2weds=";
      host.asset = "codex-code-mode-host-x86_64-unknown-linux-musl";
      host.hash = "sha256-u3/eet300seIIOEO58LHjeoII1/lwyjFabfoEbNjTsA=";
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
