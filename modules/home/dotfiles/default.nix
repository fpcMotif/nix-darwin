{ lib, ... }:

{
  imports = [
    ./bat.nix
    ./less.nix
    ./lazygit.nix
    ./rules.nix
    ./zsh.nix
    ./tmux.nix
    ./yazi.nix
    ./kitty.nix
    ./nvim.nix
    ./mpv.nix
  ];

  options.martin.dotfiles = {
    keymap.profile = lib.mkOption {
      type = lib.types.enum [
        "vim"
        "sxyazi"
      ];
      default = "vim";
      description = ''
        Keymap profile for imported dotfile assets. The default `vim` profile keeps
        conventional h/j/k/l movement; `sxyazi` preserves the reference
        u/e/n/i movement model.
      '';
    };

    bat.enable = lib.mkEnableOption "Catppuccin bat configuration managed by Home Manager";
    less.enable = lib.mkEnableOption "less keymap and environment managed by Home Manager";
    lazygit.enable = lib.mkEnableOption "lazygit configuration managed by Home Manager";
    rules.enable = lib.mkEnableOption "shared formatter and linter rule files under ~/.config/rules";

    zsh.enable = lib.mkEnableOption "reference zsh configuration managed by Home Manager";

    tmux = {
      enable = lib.mkEnableOption "reference tmux configuration managed by Home Manager";
      enableTpm = lib.mkEnableOption "TPM plugin manager bootstrap in the tmux configuration";
    };

    yazi.enable = lib.mkEnableOption "reference yazi configuration managed by Home Manager";

    kitty = {
      enable = lib.mkEnableOption "reference kitty configuration managed by Home Manager";
      allowRemoteControl = lib.mkEnableOption "kitty socket remote control at /tmp/kitty_term for cross-window integrations";
    };

    nvim = {
      enable = lib.mkEnableOption "reference Neovim Lua configuration managed by Home Manager";
      allowRuntimeManagers = lib.mkEnableOption "lazy.nvim and Mason runtime package managers inside Neovim";
    };

    mpv.enable = lib.mkEnableOption "reference mpv configuration managed by Home Manager";
  };
}
