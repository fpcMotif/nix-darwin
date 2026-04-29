{ config, lib, pkgs, ... }:

let
  cfg = config.martin.dotfiles;
  dotfilesLib = import ./lib.nix { inherit lib; };
  profileAsset = dotfilesLib.profileAsset ./. cfg.keymap.profile;
  commonAsset = path: ./assets/common/nvim + "/${path}";
  commonFiles = [
    ".luacheckrc"
    "cspell.json"
    "init.lua"
    "lazy-lock.json"
    "after/ftplugin/toml.lua"
    "lua/core.lua"
    "lua/editconfig.lua"
    "lua/selection.lua"
    "lua/terminal.lua"
    "lua/utils.lua"
    "lua/plugins/completion.lua"
    "lua/plugins/debugging.lua"
    "lua/plugins/lsp.lua"
    "lua/plugins/parser.lua"
    "lua/plugins/theme.lua"
    "lua/plugins/ui.lua"
  ];
  profileFiles = [
    "lua/keymap.lua"
    "lua/window.lua"
  ];
  mkCommonConfig = path: {
    name = "nvim/${path}";
    value.source = commonAsset path;
  };
  mkProfileConfig = path: {
    name = "nvim/${path}";
    value.source = profileAsset "nvim/${path}";
  };
in
{
  assertions = [
    {
      assertion = !cfg.nvim.enable || cfg.nvim.allowRuntimeManagers;
      message = ''
        martin.dotfiles.nvim.enable requires martin.dotfiles.nvim.allowRuntimeManagers = true
        because the reference Neovim config self-bootstraps lazy.nvim and uses Mason at runtime.
      '';
    }
  ];

  config = lib.mkIf cfg.nvim.enable {
    warnings = [
      "martin.dotfiles.nvim enables lazy.nvim and Mason runtime managers; this is intentionally outside pure Nix."
    ];

    home.activation.checkMartinDotfilesNvim = dotfilesLib.guardTargets (
      map (path: ".config/nvim/${path}") (commonFiles ++ profileFiles)
    );

    home.packages = [ pkgs.neovim ];

    xdg.configFile = lib.listToAttrs (
      (map mkCommonConfig commonFiles) ++ (map mkProfileConfig profileFiles)
    );
  };
}
