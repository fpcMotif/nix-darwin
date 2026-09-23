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
# Registered with Claude Code via the
# `claudeMcpAlwaysLoaded` activation script in
# modules/home/claude.nix (shells out to `claude mcp add` — the only way to
# write ~/.claude.json's mcpServers without risking its CLI-managed schema,
# same reasoning as claudeDesktopMcpScaffold in lsp.nix).
#
# Note: upstream renamed the repo from dmtrKovalenko/fff.nvim to
# dmtrKovalenko/fff (old URLs still 301-redirect, but we point at the
# canonical name now).
#
# Update: run `scripts/update-fff-mcp.sh`.

{ lib
, stdenvNoCC
, fetchurl
}:

let
  version = "0.11.0";

  releaseBase = "https://github.com/dmtrKovalenko/fff/releases/download/v${version}";

  sources = {
    aarch64-darwin = {
      asset = "fff-mcp-aarch64-apple-darwin";
      hash = "sha256-zGBtlBjPp3ZDdtzXsyoz5kWabLmkcYvjZrAk3Kbp/q0=";
    };
    x86_64-darwin = {
      asset = "fff-mcp-x86_64-apple-darwin";
      hash = "sha256-Mzd6j5ZELryLBtO9KGPPZqUg+XozcA4PuFoJ3XmI6GI=";
    };
    aarch64-linux = {
      asset = "fff-mcp-aarch64-unknown-linux-gnu";
      hash = "sha256-9BP9GAnxj3ukRSQBAZLSlWLWuldF4zkmvhi5nKtu24k=";
    };
    x86_64-linux = {
      asset = "fff-mcp-x86_64-unknown-linux-gnu";
      hash = "sha256-G2RZR8+ghvgIDNZBmJnjLLLFMbEiYYwRQdkVXkSc5kc=";
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
    homepage = "https://github.com/dmtrKovalenko/fff";
    changelog = "https://github.com/dmtrKovalenko/fff/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "fff-mcp";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames sources;
  };
}
