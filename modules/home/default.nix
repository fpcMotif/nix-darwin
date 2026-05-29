{ currentSystemUser, currentSystemUserHome, ... }:

{
  imports = [
    ./cleanup.nix
    ./packages.nix
    ./zsh.nix
    ./ai-cli.nix
    ./ai-model-routing.nix
    ./obsidian.nix
    ./tmux.nix
    ./git.nix
    ./jujutsu.nix
    ./ghostty.nix
    ./kitty.nix
    ./yazi.nix
    ./prompt.nix
    ./claude.nix
    ./lsp.nix
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
    # We run HM master + nixpkgs-unstable (the bleeding-edge pair). Their
    # release strings drift (e.g. HM 26.05 vs nixpkgs 26.11) purely from
    # upstream version-bump timing, not a real mismatch — silence the heuristic.
    enableNixpkgsReleaseCheck = false;
  };
}
