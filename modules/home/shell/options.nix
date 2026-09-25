{ config, lib, pkgs, ... }:

{
  options.martin.shell = {
    interactive = lib.mkOption {
      type = lib.types.enum [ "zsh" "fish" ];
      default = "zsh";
      description = ''
        The shell that owns interactive sessions: the Darwin login shell,
        the exported SHELL, and the shell Ghostty, tmux, and Zed start.
        Only this shell's config is generated; switching is one rebuild.
      '';
    };

    interactiveProgram = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default =
        if config.martin.shell.interactive == "fish"
        then lib.getExe config.programs.fish.package
        else "${pkgs.zsh}/bin/zsh";
      defaultText = lib.literalExpression "the executable of martin.shell.interactive";
      description = "The interactive shell's executable, for launchers that start it directly (tmux, Zed).";
    };

    viMode = {
      enable = lib.mkEnableOption "vi editing at the prompt via each shell's native keymaps" // {
        default = true;
      };
    };

    search = {
      enable = lib.mkEnableOption "the prompt search plane: a ^G-prefixed key plane over the fzf pickers" // {
        default = true;
      };

      prefix = lib.mkOption {
        type = lib.types.str;
        default = "^G";
        description = ''
          Search-plane prefix in two-character caret form ("^G"). It is
          explicitly removed from every keymap the plane binds, keeping it a
          PURE prefix: with KEYTIMEOUT=1 an ambiguously bound prefix makes
          two-key chords untypable.
        '';
      };

      gitObjects.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Package fzf-git-sh and make its object pickers available.";
      };

      keys = lib.mkOption {
        type = lib.types.submodule {
          options = {
            contentSearch = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = "f";
              description = "Letter for the ripgrep content picker (inserts the path at cursor); null unbinds.";
            };

            dirJump = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = "d";
              description = "Letter for the zoxide interactive directory jump; null unbinds.";
            };

            processKill = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = "k";
              description = "Letter for the process kill picker; null unbinds.";
            };
          };
        };
        default = { };
        description = "Plain letters under the prefix for this repo's pickers.";
      };
    };
  };
}
