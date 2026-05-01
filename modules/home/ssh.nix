{ lib, ... }:

{
  home.activation.checkNixManagedSsh = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    if [ -e "$HOME/.ssh/config" ] || [ -L "$HOME/.ssh/config" ]; then
      target="$(readlink "$HOME/.ssh/config" 2>/dev/null || echo "$HOME/.ssh/config")"
      case "$target" in
        /nix/store/*) : ;;
        *)
          echo "ERROR: ~/.ssh/config is not Nix-managed (target: $target)." >&2
          echo "Archive or remove it so Home Manager can take over." >&2
          exit 1
          ;;
      esac
    fi
  '';

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks."*" = {
      forwardAgent = false;
      addKeysToAgent = "no";
      compression = false;
      serverAliveInterval = 0;
      serverAliveCountMax = 3;
      hashKnownHosts = true;
      userKnownHostsFile = "~/.ssh/known_hosts";
      controlMaster = "no";
      controlPath = "~/.ssh/master-%r@%n:%p";
      controlPersist = "no";
    };

    includes = [ "~/.orbstack/ssh/config" ];
  };
}
