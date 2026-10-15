{ config, lib, pkgs, ... }:

let
  cfg = config.martin.fonts;
in
{
  options.martin.fonts.enable = lib.mkEnableOption "Martin's curated macOS font bundle (SF Mono, SF Symbols, Maple Mono NF, nerd-font symbols, Fira Code)";

  config = lib.mkIf cfg.enable {
    fonts.packages = with pkgs; [
      martin.sf-mono
      martin.sf-symbols
      maple-mono.NF-CN
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

    # fontd caches deleted store paths when /Library/Fonts/Nix Fonts changes,
    # which makes sandboxed Chromium apps render boxed "?" glyphs until cleared.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      old_fonts="$(readlink -f "/run/current-system/Library/Fonts/Nix Fonts" 2>/dev/null || true)"
      new_fonts="$(readlink -f "$systemConfig/Library/Fonts/Nix Fonts")"
      if [ -n "$old_fonts" ] && [ "$old_fonts" != "$new_fonts" ]; then
        echo "[fonts] Nix fonts changed; clearing the macOS font registry" >&2
        /usr/bin/atsutil databases -remove >/dev/null 2>&1 || true
        echo "[fonts] WARNING: log out or restart, or Chromium apps may show boxed '?' glyphs" >&2
      fi
    '';
  };
}
