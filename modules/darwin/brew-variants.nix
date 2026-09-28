{ config, lib, ... }:

let
  cfg = config.martin.brew;
in
{
  options.martin.brew = {
    homebrew.enable = lib.mkEnableOption "Homebrew as a dormant emergency scaffold; prefer pure Nix/custom derivations";
  };

  config = {
    warnings = lib.optionals cfg.homebrew.enable [
      "martin.brew.homebrew.enable is an emergency scaffold. Prefer pure Nix/custom derivations; never use Homebrew cleanup = zap."
    ];

    homebrew = lib.mkIf cfg.homebrew.enable {
      enable = true;
      onActivation.cleanup = "none";
      casks = [ ];
    };
  };
}
