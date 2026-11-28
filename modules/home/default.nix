{ currentSystemUser, currentSystemUserHome, ... }:

{
  imports = [
    ./cleanup.nix
    ./packages.nix
    ./session.nix
    ./shell/zsh.nix
    ./shell/direnv.nix
    ./shell/fzf.nix
    ./shell/zoxide.nix
    ./ai-cli.nix
    ./pi.nix
    ./ai-model-routing.nix
    ./agent-surface.nix
    ./skill-placement.nix
    ./skill-bundle.nix
    ./agent-instructions.nix
    ./obsidian.nix
    ./tmux.nix
    ./git.nix
    ./hk.nix
    ./doc-lock
    ./recall
    ./jujutsu.nix
    ./workspace-backend
    ./ghostty.nix
    ./kitty.nix
    ./yazi.nix
    ./prompt.nix
    ./claude.nix
    ./antigravity
    ./lsp.nix
    ./droid.nix
    ./zed.nix
    ./crush.nix
    ./amp.nix
    ./ssh.nix
    ./cursor.nix
    ./skill-router.nix
    ./iets.nix
  ];

  home = {
    username = currentSystemUser;
    homeDirectory = currentSystemUserHome;
    stateVersion = "24.05";
    # We run HM master with nixpkgs-unstable. Their release strings drift
    # (e.g. HM 26.05 vs nixpkgs 26.11) from upstream version-bump timing,
    # not a real mismatch, so silence the heuristic.
    enableNixpkgsReleaseCheck = false;
  };
}
