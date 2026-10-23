{ lib, pkgs ? null }:

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
  pythonExtensions = {
    ".py" = "python";
    ".pyi" = "python";
  };

  validTargets = [ "claude" "codex" "zed" ];

  servers = {
    tsrs = {
      package = "tsrs";
      command = "tsrs";
      args = [ "--lsp" "--stdio" ];
      extensions = jsExtensions;
      targets = [ "claude" "codex" "zed" ];
      zedName = "typescript-ls";
    };
    oxlint = {
      package = "oxlint";
      command = "oxlint";
      args = [ "--lsp" ];
      extensions = jsExtensions // oxlintExtraExtensions;
      isLinter = true;
      targets = [ "claude" "codex" "zed" ];
    };
    oxfmt = {
      package = "oxfmt";
      command = "oxfmt";
      args = [ "--lsp" ];
      extensions = { };
      targets = [ "zed" ];
    };
    astro = {
      package = "astro-language-server";
      command = "astro-language-server";
      args = [ "--stdio" ];
      extensions = { ".astro" = "astro"; };
      targets = [ "claude" "codex" ];
    };
    svelte = {
      package = "svelte-language-server";
      command = "svelteserver";
      args = [ "--stdio" ];
      extensions = { ".svelte" = "svelte"; };
      targets = [ "claude" "codex" ];
    };
    tailwindcss = {
      package = "tailwindcss-language-server";
      command = "tailwindcss-language-server";
      args = [ "--stdio" ];
      extensions = tailwindExtensions;
      targets = [ "claude" "codex" ];
    };
    gopls = {
      package = "gopls";
      command = "gopls";
      args = [ ];
      extensions = { ".go" = "go"; };
      targets = [ "claude" "codex" ];
    };
    rust = {
      package = null;
      command = "rust-analyzer";
      args = [ ];
      extensions = { ".rs" = "rust"; };
      targets = [ "claude" "codex" ];
    };
    sourcekit = {
      package = "sourcekit-lsp";
      command = "sourcekit-lsp";
      args = [ ];
      extensions = { ".swift" = "swift"; };
      targets = [ "claude" "codex" ];
    };
    pyright = {
      package = "basedpyright";
      command = "basedpyright-langserver";
      args = [ "--stdio" ];
      extensions = pythonExtensions;
      targets = [ "claude" "codex" "zed" ];
      zedName = "basedpyright";
      zedArgs = [ ];
    };
    ruff = {
      package = "ruff";
      command = "ruff";
      args = [ "server" ];
      extensions = pythonExtensions;
      isLinter = true;
      targets = [ "claude" "codex" "zed" ];
    };
    lua = {
      package = "lua-language-server";
      command = "lua-language-server";
      args = [ ];
      extensions = { ".lua" = "lua"; };
      targets = [ "claude" "codex" ];
    };
    nixd = {
      package = "nixd";
      command = "nixd";
      args = [ ];
      extensions = { ".nix" = "nix"; };
      targets = [ "zed" ];
    };
  };

  codexOrder = [
    "tsrs"
    "oxlint"
    "astro"
    "svelte"
    "tailwindcss"
    "gopls"
    "rust"
    "sourcekit"
    "pyright"
    "ruff"
    "lua"
  ];

  serversFor = target:
    lib.filterAttrs (_: s: builtins.elem target s.targets) servers;

  tomlList = items:
    lib.concatMapStringsSep ", " (item: ''"${item}"'') items;

  tomlExts = attrs:
    tomlList (builtins.attrNames attrs);

  renderCodexServer = name:
    let
      s = servers.${name};
      argsLine = lib.optionalString (s.args != [ ]) "args = [${tomlList s.args}]\n    ";
      linterLine = lib.optionalString (s.isLinter or false) "\n    is_linter = true";
    in
    ''
      [lsp.servers.${name}]
      command = "${s.command}"
      ${argsLine}extensions = [${tomlExts s.extensions}]${linterLine}'';

  codexToml = ''

    # --- managed by ~/nix-config/modules/shared/codex-lsp.nix ---
    [lsp]
    enabled = true
    diagnosticsOnWrite = true
    diagnosticsOnEdit = false
    formatOnWrite = false

    ${lib.concatMapStringsSep "\n\n    " renderCodexServer codexOrder}
    # --- end managed block ---
  '';

  claudeAdapter = {
    lspServers = lib.mapAttrs
      (_: s: {
        inherit (s) command args;
        extensionToLanguage = s.extensions;
      } // lib.optionalAttrs (s.isLinter or false) {
        isLinter = true;
      })
      (serversFor "claude");
  };

  zedAdapter =
    assert pkgs != null;
    lib.mapAttrs'
      (name: s:
        let
          zedArgs = s.zedArgs or s.args;
          path = "${pkgs.${s.package}}/bin/${s.command}";
        in
        lib.nameValuePair (s.zedName or name) {
          binary = { inherit path; } // lib.optionalAttrs (zedArgs != [ ]) {
            arguments = zedArgs;
          };
        }
      )
      (serversFor "zed");

  packagesForTargets = targets:
    assert pkgs != null;
    lib.unique (lib.concatMap
      (s: lib.optional (s.package != null && lib.any (t: builtins.elem t s.targets) targets) pkgs.${s.package})
      (lib.attrValues servers));
in
assert lib.all
  (s:
  s.command != ""
  && s.targets != [ ]
  && lib.all (t: builtins.elem t validTargets) s.targets
  && ((builtins.elem "claude" s.targets || builtins.elem "codex" s.targets) -> (s.extensions != { } && lib.all (lib.hasPrefix ".") (builtins.attrNames s.extensions)))
    && (builtins.elem "zed" s.targets -> s.package != null)
  )
  (lib.attrValues servers);
assert lib.all (name: builtins.elem "codex" servers.${name}.targets) codexOrder;
{
  inherit jsExtensions oxlintExtraExtensions tailwindExtensions servers;

  toml = codexToml;

  packages =
    if pkgs == null then [ ]
    else packagesForTargets [ "claude" "codex" ] ++ [
      pkgs.typescript
      pkgs.emmet-language-server
      pkgs.mcp-language-server
    ];

  zedPackages =
    if pkgs == null then [ ]
    else packagesForTargets [ "zed" ] ++ [
      pkgs.bash-language-server
      pkgs.lua-language-server
      pkgs.gopls
      pkgs.martin.rust-toolchain
    ];

  adapters = {
    claude = claudeAdapter;
    codex = codexToml;
    zed = zedAdapter;
  };
}

