{ lib
, stdenvNoCC
, fetchurl
}:

let
  version = "0.11.1-nightly.ab3002a";

  releaseBase = "https://github.com/dmtrKovalenko/fff/releases/download/${version}";

  sources = {
    aarch64-darwin = {
      asset = "fff-mcp-aarch64-apple-darwin";
      hash = "sha256-v8DEQ3sVtqvfoZ52rtUjqvr3Fz4RHAEtsHWn2XqXmC4=";
    };
    x86_64-darwin = {
      asset = "fff-mcp-x86_64-apple-darwin";
      hash = "sha256-fIrMdH+ievzx2M4cSqFPGYWOkQcBhx0dTMrtwA7CJZ0=";
    };
    aarch64-linux = {
      asset = "fff-mcp-aarch64-unknown-linux-gnu";
      hash = "sha256-IRAI82AZgorD1E8/J+MRy/jDfwImmVO8iv5zVoGMcvc=";
    };
    x86_64-linux = {
      asset = "fff-mcp-x86_64-unknown-linux-gnu";
      hash = "sha256-TFTNjbaKQWOrpFUyTUS1kdGYSaFEFNgNFaWWJT/JUqA=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "fff-mcp is not packaged for ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "fff-mcp";
  inherit version;

  src = fetchurl {
    url = "${releaseBase}/${source.asset}";
    inherit (source) hash;
  };

  dontUnpack = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm0755 "$src" "$out/bin/fff-mcp"
    runHook postInstall
  '';

  meta = {
    description = "Frecency-ranked, git-aware file search MCP server for AI agents (fff)";
    homepage = "https://github.com/dmtrKovalenko/fff";
    changelog = "https://github.com/dmtrKovalenko/fff/releases/tag/${version}";
    license = lib.licenses.mit;
    mainProgram = "fff-mcp";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames sources;
  };
}
