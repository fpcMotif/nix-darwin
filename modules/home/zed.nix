{ lib, pkgs, ... }:

# Prebuilt nightly .dmg only: building inputs.zed-upstream compiles 3000+
# uncached crates. Darwin only: the nightly host ships no Linux build.
# `mutable*` keeps Zed's in-app settings UI working.

let
  routing = import ../shared/agent-model-routing.nix { inherit lib; };
  openAiFavorite = job: {
    provider = "openai-subscribed";
    model = routing.modelId job;
    enable_thinking = true;
    effort = routing.effort job;
  };

  # oxfmt formats through the oxc extension's `oxfmt` server. Prettier stays
  # off so Zed never tries to npm-install it (npm is the bun shim here).
  oxfmtFormatted = {
    formatter.language_server.name = "oxfmt";
    prettier.allowed = false;
    format_on_save = "on";
  };

  # A list without "..." replaces Zed's defaults (vtsls, eslint, tailwind),
  # so only these servers run.
  jsLanguage = oxfmtFormatted // {
    language_servers = [ "typescript-ls" "oxlint" "oxfmt" ];
    code_actions_on_format."source.fixAll.oxc" = true;
  };
in
{
  xdg.configFile = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    "zed/settings.json".force = true;
  };

  programs.zed-editor = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    package = pkgs.martin.zed-nightly-bin;

    extraPackages = with pkgs; [
      # Nix
      nixd

      # TypeScript / JavaScript
      typescript # TS 7 native `tsc`, also the LSP via `tsc --lsp`
      oxlint # fast linter (oxc)
      oxfmt # fast formatter (oxc)

      # Python (Astral stack)
      ruff # `ruff server` = LSP, also formatter & linter
      basedpyright # type checker

      # Other
      bash-language-server
      lua-language-server
      gopls
      martin.rust-toolchain
    ];

    extensions = [
      "nix"
      "toml"
      "git-firefly"
      "docker"
      "catppuccin"
      "make"
      "dockerfile"
      "html"
      # Toolchain extensions — these glue the binaries above into Zed's
      # language workflow (code actions, diagnostics surfacing, etc.).
      "ruff"
      "basedpyright"
      "tsgo"
      "oxc"
    ];

    mutableUserSettings = false;
    mutableUserKeymaps = false;

    userSettings = {
      theme = {
        mode = "system";
        light = "One Light";
        dark = "One Dark";
      };
      vim_mode = true;
      ui_font_size = 16;
      buffer_font_size = 15;
      buffer_font_family = "JetBrains Mono";
      autosave = "on_focus_change";
      format_on_save = "on";
      tab_size = 2;

      cli_default_open_behavior = "existing_window";
      diff_view_style = "unified";
      auto_update_extensions = {
        oxc = true;
      };

      context_servers = {
        mcp-server-context7 = {
          enabled = true;
          remote = false;
          settings = {
            context7_api_key = "";
          };
        };
      };

      agent_servers = {
        pi-acp = {
          favorite_models = map routing.bareSelector routing.adapters.zedFavorites;
          type = "registry";
        };
        opencode.type = "registry";
        codex-acp.type = "registry";
        claude-acp.type = "registry";
        amp-acp.type = "registry";
        factory-droid.type = "registry";
        antigravity-acp.type = "registry";
      };

      project_panel.dock = "right";
      outline_panel.dock = "right";
      collaboration_panel.dock = "right";
      git_panel.dock = "right";

      agent = {
        dock = "left";
        single_file_review = true;
        thinking_display = "preview";
        default_profile = "write";

        favorite_models = map openAiFavorite routing.adapters.zedFavorites ++ [
          {
            provider = "zed.dev";
            model = "claude-fable-5";
            enable_thinking = true;
            effort = "max";
          }
        ];

        default_model = {
          provider = "zed.dev";
          model = "claude-fable-5";
          enable_thinking = true;
          effort = "max";
        };

        model_parameters = [ ];

        tool_permissions = {
          default = "allow";
          tools = {
            terminal.default = "allow";
            edit_file.default = "allow";
            write_file.default = "allow";
            delete_path.default = "allow";
            move_path.default = "allow";
            copy_path.default = "allow";
            create_directory.default = "allow";
            fetch.default = "allow";
            search_web.default = "allow";
          };
        };

        sandbox_permissions = {
          allow_unsandboxed = true;
          allow_all_hosts = true;
          allow_fs_write_all = true;
          warn_ntfs_grants = false;
        };

        profiles = {
          write = {
            name = "Write";
            enable_all_context_servers = true;
            context_servers = { };
            tools = {
              search_web = true;
              copy_path = true;
              create_directory = true;
              delete_path = true;
              diagnostics = true;
              edit_file = true;
              write_file = true;
              fetch = true;
              list_directory = true;
              project_notifications = true;
              move_path = true;
              now = true;
              find_path = true;
              read_file = true;
              grep = true;
              terminal = true;
              thinking = true;
              open = true;
              skill = true;
              spawn_agent = true;
            };
          };
          ask = {
            name = "Ask";
            enable_all_context_servers = false;
            context_servers = { };
            tools = {
              search_web = true;
              terminal = true;
              move_path = true;
              edit_file = true;
              copy_path = true;
              delete_path = true;
              diagnostics = true;
              fetch = true;
              list_directory = true;
              project_notifications = true;
              now = true;
              find_path = true;
              read_file = true;
              open = true;
              grep = true;
              thinking = true;
              create_directory = true;
              skill = true;
            };
          };
        };
      };

      terminal = {
        font_family = "JetBrains Mono";
        font_size = 13;
        shell.program = "${pkgs.zsh}/bin/zsh";
      };

      # ---- LSP servers ------------------------------------------------------
      lsp = {
        # Nix
        nixd.binary.path = "${pkgs.nixd}/bin/nixd";

        # A pinned `binary.path` makes Zed launch that binary directly and
        # skip the extension's npm install, which fails on the bun shim.
        typescript-ls.binary = {
          path = "${pkgs.typescript}/bin/tsc";
          arguments = [ "--lsp" "--stdio" ];
        };
        oxlint.binary = {
          path = "${pkgs.oxlint}/bin/oxlint";
          arguments = [ "--lsp" ];
        };
        oxfmt.binary = {
          path = "${pkgs.oxfmt}/bin/oxfmt";
          arguments = [ "--lsp" ];
        };

        # Python — ruff serves as LSP via its built-in `ruff server`.
        ruff.binary = {
          path = "${pkgs.ruff}/bin/ruff";
          arguments = [ "server" ];
        };
        # basedpyright for types.
        basedpyright.binary.path = "${pkgs.basedpyright}/bin/basedpyright-langserver";
      };

      # ---- Per-language overrides ------------------------------------------
      languages = {
        # JavaScript also covers .jsx; Zed has no separate JSX language.
        TypeScript = jsLanguage;
        TSX = jsLanguage;
        JavaScript = jsLanguage;

        Python = {
          # ruff first (lint + format), basedpyright for types. The "!"
          # prefix disables Zed's built-in pyright bundling.
          language_servers = [ "ruff" "basedpyright" "!pyright" ];
          format_on_save = "on";
          formatter = { language_server.name = "ruff"; };
          code_actions_on_format = {
            "source.fixAll.ruff" = true;
            "source.organizeImports.ruff" = true;
          };
        };

        Nix = {
          language_servers = [ "nixd" ];
          format_on_save = "on";
        };

        # No vscode-langservers-extracted: Zed installs them via `npm`, the bun
        # shim here, which fails. "..." keeps the other servers.
        HTML = oxfmtFormatted // {
          language_servers = [ "!vscode-html-language-server" "..." ];
        };
        CSS = oxfmtFormatted // {
          language_servers = [ "!vscode-css-language-server" "..." ];
        };
        JSON = oxfmtFormatted // {
          language_servers = [ "!json-language-server" "..." ];
        };
        JSONC = oxfmtFormatted // {
          language_servers = [ "!json-language-server" "..." ];
        };
        Markdown = oxfmtFormatted;
        YAML = oxfmtFormatted;
        TOML = oxfmtFormatted;
      };


      git = {
        inline_blame = {
          enabled = true;
          show_commit_summary = true;
        };
      };

      telemetry = {
        diagnostics = true;
        metrics = true;
        anthropic_retention = true;
      };

      # Nix pins Zed, so self-update must stay off: it fails on the read-only
      # bundle and leaves orphan instances that block launch. Bump the version
      # with scripts/update-zed-nightly.sh.
      auto_update = false;
    };

    userKeymaps = [
      {
        context = "Workspace";
        bindings = {
          "cmd-shift-t" = "workspace::NewTerminal";
        };
      }
    ];
  };
}
