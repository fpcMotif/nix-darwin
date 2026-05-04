{ config, lib, pkgs, ... }:

let
  cfg = config.martin.fonts;
in
{
  options.martin.fonts.enable = lib.mkEnableOption "Martin's curated macOS font bundle (SF Mono, SF Symbols, Maple Mono NF, nerd-font symbols, Fira Code)";

  config = lib.mkIf cfg.enable {
    fonts.packages = with pkgs; [
      # Apple-native — packaged from Apple's developer downloads.
      martin.sf-mono
      martin.sf-symbols

      # CJK + ligatures monospace used by Ghostty/Kitty/Zed.
      maple-mono.NF-CN

      # Common dev fonts and icon/symbol fallback fonts from upstream nixpkgs.
      fira-code
      material-symbols
      nerd-fonts.dejavu-sans-mono
      nerd-fonts.fira-code
      nerd-fonts.roboto-mono
      nerd-fonts.symbols-only
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      source-han-mono
    ];
  };
}
