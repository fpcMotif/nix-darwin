{ config, ... }:

{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    # Trust owned project roots so flake.lock and .envrc updates do not prompt
    # for direnv allow. Omit ~/Downloads where untrusted repos land.
    config.whitelist.prefix = [
      "${config.home.homeDirectory}/nix-config"
      "${config.home.homeDirectory}/devv"
      "${config.home.homeDirectory}/Burrow"
      "${config.home.homeDirectory}/ghostty"
    ];
    # Hide the 50-variable export diff on shell reload while keeping status lines.
    # Errors bypass log_filter so blocked or failing .envrc files still print.
    config.global.log_filter = "^(loading|using|nix-direnv)";
  };
}
