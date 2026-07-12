# fff-mcp — prebuilt binary release of the fff MCP server (frecency-ranked,
# git-aware file search / grep for AI agents: https://github.com/dmtrKovalenko/fff).
#
# Why prebuilt, not built from source: fff-mcp is one crate inside a large
# multi-crate Rust monorepo (Neovim plugin + Lua/mlua FFI + N language
# bindings). Vendoring the whole workspace for one ~7MB binary is the same
# "recompile the world for one tool" problem codex.nix / droid.nix /
# zed-nightly-bin.nix already solve by fetching the maintainer's own
# release asset instead.
#
# Registered with Claude Code via the `claudeMcpFff` activation script in
# modules/home/claude.nix (shells out to `claude mcp add` — the only way to
# write ~/.claude.json's mcpServers without risking its CLI-managed schema,
# same reasoning as claudeDesktopMcpScaffold in lsp.nix).
#
# Update: bump `version` and the four hashes from
# https://github.com/dmtrKovalenko/fff.nvim/releases — or copy them
# straight out of that repo's Formula/fff-mcp.rb (same assets; hex sha256
# there converts 1:1 to the SRI form below via
# `nix hash convert --hash-algo sha256 --to sri <hex>`).

{ lib
, stdenvNoCC
, fetchurl
}:

let
  version = "0.9.6";

  releaseBase = "https://github.com/dmtrKovalenko/fff.nvim/releases/download/v${version}";

  sources = {
    aarch64-darwin = {
      asset = "fff-mcp-aarch64-apple-darwin";
      hash = "sha256-Kaf63q+wYvPllUsauMaeFNyiT14GHNjTseobqzhaN1Q=";
    };
    x86_64-darwin = {
      asset = "fff-mcp-x86_64-apple-darwin";
      hash = "sha256-WCWTJMLBOhtvJPExOMLNPq6f8g4FIBpTm+uPIESmUao=";
    };
    aarch64-linux = {
      asset = "fff-mcp-aarch64-unknown-linux-gnu";
      hash = "sha256-keb6FOBAWI3JLehU41AgU28eJFjOM4aytyey56iPZoQ=";
    };
    x86_64-linux = {
      asset = "fff-mcp-x86_64-unknown-linux-gnu";
      hash = "sha256-0b0riaeejtpxsXVCYEmc7B/qr9Kt83LpI3HI1raFCaM=";
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

  # Releases publish the bare executable, not an archive — nothing to unpack.
  dontUnpack = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm0755 "$src" "$out/bin/fff-mcp"
    runHook postInstall
  '';

  meta = {
    description = "Frecency-ranked, git-aware file search MCP server for AI agents (fff)";
    homepage = "https://github.com/dmtrKovalenko/fff.nvim";
    changelog = "https://github.com/dmtrKovalenko/fff.nvim/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "fff-mcp";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames sources;
  };
}
