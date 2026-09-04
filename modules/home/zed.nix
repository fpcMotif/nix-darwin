{ lib, pkgs, ... }:

# Zed editor — fully Nix-managed via Home Manager's `programs.zed-editor`
# module. The editor binary comes from `pkgs.martin.zed-nightly-bin`, which
# fetches the prebuilt nightly `.dmg` from
# `zed-nightly-host.nyc3.digitaloceanspaces.com` — Nix never compiles Zed.
# `scripts/update-zed-nightly.sh` (run hourly by .github/workflows/auto-update.yml)
# follows the `nightly/latest` redirect chain to keep the pin fresh.
# Never put `inputs.zed-upstream` (raw source flake) on the rebuild path: that
# triggers a 3000+ cargo-crate compile with zero cache hits.
# Extensions install in-app on first launch from the strings declared below;
# LSPs are wired to nixpkgs derivations so nothing reaches outside the Nix store.
#
# Platform: `zed-nightly-bin` only ships aarch64-darwin .dmg artifacts (Zed's
# nightly host has no Linux build, and the flake's supportedSystems list
# intentionally drops x86_64-darwin), so this module is gated to Darwin via
# `lib.mkIf`. On Linux (WSL / x230 / vm-aarch64-utm) the config collapses to
# `{}` and Home Manager never reaches for a derivation that would throw on
# `home.packages` materialization. Re-enable per-host with a Linux-capable
# package (e.g. `pkgs.zed-editor` from nixpkgs) if a Linux Zed becomes useful.
#
# Toolchain choices:
#   TypeScript / JS  — tsgo (typescript-go, the Go rewrite from the TS team)
#                      as the type-checker; oxlint (oxc family) for linting;
#                      oxfmt (oxc family) for formatting.
#                      vtsls is kept on PATH as a fallback for projects that
#                      can't use tsgo yet.
#   Python           — ruff (Astral, same team as uv) as both linter AND
#                      formatter via `ruff server`; basedpyright for type
#                      checking. No black, no flake8, no isort needed.
#   Nix              — nixd
#   Bash / Lua / Go / Rust — upstream LSPs from nixpkgs.
#
# `mutable*` flags keep the relevant config files mergeable so Zed's in-app
# preferences UI continues to work — flip a flag to false to make Nix the
# single source of truth for that file.

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
      typescript-go # provides `tsgo` binary
      vtsls # fallback TS LSP for projects tsgo can't handle yet
      oxlint # fast linter (oxc)
      oxfmt # fast formatter (oxc)

      # Python (Astral stack)
      ruff # `ruff server` = LSP, also formatter & linter
      basedpyright # type checker

      # Other
      bash-language-server
      lua-language-server
      gopls
      rust-analyzer
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
    ];

    mutableUserSettings = false;
    mutableUserKeymaps = false;

    userSettings = {
      theme = {
        mode = "system";
        light = "One Light";
        dark = "One Dark";
      };
      vim_mode = false;
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
          favorite_models = [
            "openai-codex/gpt-5.5"
            "openai-codex/gpt-5.3-codex-spark"
          ];
          type = "registry";
        };
        opencode.type = "registry";
        codex-acp.type = "registry";
        claude-acp.type = "registry";
        amp-acp.type = "registry";
        factory-droid.type = "registry";
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

        favorite_models = [
          {
            provider = "openai-subscribed";
            model = "gpt-5.3-codex";
            enable_thinking = true;
            effort = "xhigh";
          }
          {
            provider = "openai-subscribed";
            model = "gpt-5.5";
            enable_thinking = true;
            effort = "xhigh";
          }
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

        # TypeScript / JS — use tsgo as the language server. tsgo speaks the
        # standard tsserver protocol and Zed's built-in TypeScript adapter
        # routes to whatever binary is on PATH or pinned here.
        typescript-language-server.binary = {
          path = "${pkgs.typescript-go}/bin/tsgo";
          arguments = [ "lsp" "--stdio" ];
        };
        # Keep vtsls available as an explicit fallback profile for projects
        # that opt out of tsgo via .zed/settings.json.
        vtsls.binary.path = "${pkgs.vtsls}/bin/vtsls";

        # Python — ruff serves as LSP via its built-in `ruff server`.
        ruff.binary = {
          path = "${pkgs.ruff}/bin/ruff";
          arguments = [ "server" ];
        };
        # basedpyright for types.
        basedpyright.binary.path = "${pkgs.basedpyright}/bin/basedpyright-langserver";

        # CSS
        vscode-css-language-server.settings.css.lint.unknownAtRules = "ignore";
      };

      # ---- Per-language overrides ------------------------------------------
      languages = {
        TypeScript = {
          language_servers = [ "typescript-language-server" "!vtsls" ];
          formatter = {
            external = {
              command = "${pkgs.oxfmt}/bin/oxfmt";
              arguments = [ "--stdin" "--stdin-filepath" "{buffer_path}" ];
            };
          };
          format_on_save = "on";
          # Have oxlint surface code actions on save when its Zed extension
          # is installed manually; harmless when it isn't.
          code_actions_on_format = { "source.fixAll.oxc" = true; };
        };

        TSX = {
          language_servers = [ "typescript-language-server" "!vtsls" ];
          formatter = {
            external = {
              command = "${pkgs.oxfmt}/bin/oxfmt";
              arguments = [ "--stdin" "--stdin-filepath" "{buffer_path}" ];
            };
          };
          format_on_save = "on";
        };

        JavaScript = {
          language_servers = [ "typescript-language-server" "!vtsls" ];
          formatter = {
            external = {
              command = "${pkgs.oxfmt}/bin/oxfmt";
              arguments = [ "--stdin" "--stdin-filepath" "{buffer_path}" ];
            };
          };
          format_on_save = "on";
        };

        JSX = {
          language_servers = [ "typescript-language-server" "!vtsls" ];
          formatter = {
            external = {
              command = "${pkgs.oxfmt}/bin/oxfmt";
              arguments = [ "--stdin" "--stdin-filepath" "{buffer_path}" ];
            };
          };
          format_on_save = "on";
        };

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
      };

      assistant = {
        version = "2";
        enabled = true;
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

      # Nix pins the Zed version (pkgs.martin.zed-nightly-bin) and the darwin
      # module owns the /Applications bundle, so Zed must never self-update:
      # its updater downloads a newer nightly and tries to rsync over the
      # read-only store / root-owned bundle, which fails with "Permission
      # denied" and churns/relaunches the app — leaving orphaned instances
      # from old (GC-able) store paths that wedge the single-instance lock
      # and make Zed "fail to open". Version bumps come from
      # scripts/update-zed-nightly.sh + darwin-rebuild instead.
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
