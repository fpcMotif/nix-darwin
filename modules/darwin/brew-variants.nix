{ config, lib, ... }:

let
  cfg = config.martin.brew;
in
{
  options.martin.brew = {
    homebrew.enable = lib.mkEnableOption "Homebrew as a dormant emergency scaffold; prefer pure Nix/custom derivations";
    zerobrew.enable = lib.mkEnableOption "zerobrew as a documented, disabled brew-variant scaffold";
    zigbrew.enable = lib.mkEnableOption "zigbrew as a documented, disabled brew-variant scaffold";
  };

  config = {
    assertions = [
      {
        assertion = !cfg.zerobrew.enable;
        message = "martin.brew.zerobrew.enable is documentation-only for now. Keep zerobrew as a manual scratchpad, not a declarative source of truth.";
      }
      {
        assertion = !cfg.zigbrew.enable;
        message = "martin.brew.zigbrew.enable is documentation-only for now. Keep zigbrew as a manual scratchpad, not a declarative source of truth.";
      }
    ];

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
