{ pkgs, lib, ... }:

# Zed editor — fully Nix-managed via the upstream `programs.zed-editor`
# home-manager module. zed-editor itself comes from nixpkgs (auto-upgraded
# nightly via `nix flake update nixpkgs`); extensions install in-app on first
# launch from the strings declared below; LSPs are wired to nixpkgs
# derivations so nothing reaches outside the Nix store.
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
  programs.zed-editor = {
    enable = true;

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
      vim_mode = true;
      ui_font_size = 16;
      buffer_font_size = 15;
      buffer_font_family = "JetBrains Mono";
      autosave = "on_focus_change";
      format_on_save = "on";
      tab_size = 2;

      agent_servers = {
        pi-acp = {
          favorite_models = [
            "openai-codex/gpt-5.5"
            "openai-codex/gpt-5.3-codex-spark"
          ];
          type = "registry";
        };
        opencode.type = "registry";
        gemini = {
          favorite_models = [ "gemini-3.1-pro-preview" ];
          type = "registry";
        };
        codex-acp.type = "registry";
        claude-acp.type = "registry";
        amp-acp.type = "registry";
      };

      project_panel.dock = "left";
      outline_panel.dock = "left";
      collaboration_panel.dock = "left";
      git_panel.dock = "left";
      agent = {
        dock = "right";
        favorite_models = [ ];
        model_parameters = [ ];
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

      git.inline_blame.enabled = true;
      telemetry = {
        diagnostics = false;
        metrics = false;
      };
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
