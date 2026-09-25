{ config, lib, pkgs, ... }:

let
  user = config.system.primaryUser;
  fishSelected = config.home-manager.users.${user}.martin.shell.interactive == "fish";
in
{
  # macOS scripts and agent shells (Claude Code's Bash tool) run /bin/zsh
  # whichever shell is interactive, so its Nix environment stays on.
  programs.zsh.enable = true;

  programs.fish = lib.mkIf fishSelected {
    enable = true;
    # Translate the nix-darwin environment to fish at build time, instead of
    # starting bash through foreign-env on every fish start.
    useBabelfish = true;
  };

  environment.shells = [
    pkgs.zsh
  ] ++ lib.optionals fishSelected [
    pkgs.fish
  ];

  # nix-darwin sets UserShell only for users in knownUsers. It refuses to
  # delete the primary user, and it deletes no user with uid <= 501. Keeping
  # the user known in zsh mode is what writes /bin/zsh back on rollback.
  users.knownUsers = [ user ];
  users.users.${user}.shell = if fishSelected then pkgs.fish else "/bin/zsh";
}
