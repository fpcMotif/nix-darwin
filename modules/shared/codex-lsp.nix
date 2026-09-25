{ lib }:

let
  jsExtensions = {
    ".ts" = "typescript";
    ".tsx" = "typescriptreact";
    ".mts" = "typescript";
    ".cts" = "typescript";
    ".js" = "javascript";
    ".jsx" = "javascriptreact";
    ".mjs" = "javascript";
    ".cjs" = "javascript";
  };
  oxlintExtraExtensions = {
    ".vue" = "vue";
    ".astro" = "astro";
    ".svelte" = "svelte";
  };
  tailwindExtensions = jsExtensions // oxlintExtraExtensions // {
    ".html" = "html";
    ".css" = "css";
  };
  tomlExts = attrs:
    lib.concatMapStringsSep ", " (extension: ''"${extension}"'')
      (builtins.attrNames attrs);
in
{
  inherit jsExtensions oxlintExtraExtensions tailwindExtensions;

  toml = ''

    # --- managed by ~/nix-config/modules/shared/codex-lsp.nix ---
    [lsp]
    enabled = true
    diagnosticsOnWrite = true
    diagnosticsOnEdit = false
    formatOnWrite = false

    [lsp.servers.tsc]
    command = "tsc"
    args = ["--lsp", "--stdio"]
    extensions = [${tomlExts jsExtensions}]

    [lsp.servers.oxlint]
    command = "oxlint"
    args = ["--lsp"]
    extensions = [${tomlExts (jsExtensions // oxlintExtraExtensions)}]
    is_linter = true

    [lsp.servers.astro]
    command = "astro-language-server"
    args = ["--stdio"]
    extensions = [".astro"]

    [lsp.servers.svelte]
    command = "svelteserver"
    args = ["--stdio"]
    extensions = [".svelte"]

    [lsp.servers.tailwindcss]
    command = "tailwindcss-language-server"
    args = ["--stdio"]
    extensions = [${tomlExts tailwindExtensions}]

    [lsp.servers.gopls]
    command = "gopls"
    extensions = [".go"]

    [lsp.servers.rust]
    command = "rust-analyzer"
    extensions = [".rs"]

    [lsp.servers.sourcekit]
    command = "sourcekit-lsp"
    extensions = [".swift"]

    [lsp.servers.pyright]
    command = "basedpyright-langserver"
    args = ["--stdio"]
    extensions = [".py", ".pyi"]

    [lsp.servers.ruff]
    command = "ruff"
    args = ["server"]
    extensions = [".py", ".pyi"]
    is_linter = true

    [lsp.servers.lua]
    command = "lua-language-server"
    extensions = [".lua"]
    # --- end managed block ---
  '';
}
