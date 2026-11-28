{ lib
, stdenvNoCC
, fetchurl
}:

let
  version = "0.11.1-nightly.eb58401";

  releaseBase = "https://github.com/dmtrKovalenko/fff/releases/download/${version}";

  sources = {
    aarch64-darwin = {
      asset = "fff-mcp-aarch64-apple-darwin";
      hash = "sha256-VEtQHz4RCOfFQXisHRYld8s2IV0C+i5n/yZof8kwSgU=";
    };
    x86_64-darwin = {
      asset = "fff-mcp-x86_64-apple-darwin";
      hash = "sha256-PcYYhoLB2u8E/C3shXQfTdQD77VUOvE2LwP+2RWlLpw=";
    };
    aarch64-linux = {
      asset = "fff-mcp-aarch64-unknown-linux-gnu";
      hash = "sha256-n5lqvDN8k0gV5CtfqYdZGJcj4yZibKv8RKIY+ZApP6g=";
    };
    x86_64-linux = {
      asset = "fff-mcp-x86_64-unknown-linux-gnu";
      hash = "sha256-9Zr8XuV7iYOrGWvacWhf94D9Hx5uoF1RwsPhDWX1OSY=";
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
