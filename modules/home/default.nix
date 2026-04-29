{ currentSystemUser, currentSystemUserHome, ... }:

{
  imports = [
    ./cleanup.nix
    ./packages.nix
    ./zsh.nix
    ./ai-cli.nix
    ./obsidian.nix
    ./tmux.nix
    ./git.nix
    ./jujutsu.nix
    ./ghostty.nix
    ./kitty.nix
    ./yazi.nix
    ./prompt.nix
    ./skills.nix
    ./claude-code.nix
    ./droid.nix
    ./opencode.nix
    ./zed.nix
    ./crush.nix
    ./amp.nix
    ./ssh.nix
    ./cursor.nix
  ];

  home = {
    username = currentSystemUser;
    homeDirectory = currentSystemUserHome;
    stateVersion = "24.05";
  };
}
