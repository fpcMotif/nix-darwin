{ currentSystemUser, currentSystemUserHome, ... }:

{
  imports = [
    ./packages.nix
    ./zsh.nix
    ./tmux.nix
    ./git.nix
    ./ghostty.nix
    ./kitty.nix
    ./yazi.nix
    ./prompt.nix
    ./skills.nix
    ./claude-code.nix
    ./droid.nix
    ./opencode.nix
    ./zed.nix
  ];

  home = {
    username = currentSystemUser;
    homeDirectory = currentSystemUserHome;
    stateVersion = "24.05";
  };
}
