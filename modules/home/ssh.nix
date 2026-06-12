{ lib, pkgs, ... }:

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

    # `settings` replaces the deprecated `matchBlocks` alias. Keys are Host
    # patterns; values use OpenSSH directive names (not HM camelCase). These
    # restate the old HM defaults that enableDefaultConfig = false drops.
    settings."*" = {
      ForwardAgent = false;
      AddKeysToAgent = "no";
      Compression = false;
      ServerAliveInterval = 0;
      ServerAliveCountMax = 3;
      HashKnownHosts = false;
      UserKnownHostsFile = "~/.ssh/known_hosts";
      ControlMaster = "no";
      ControlPath = "~/.ssh/master-%r@%n:%p";
      ControlPersist = "no";
    };

    # OrbStack is a macOS container/VM runtime; its ssh include has no Linux
    # counterpart.
    includes = lib.optionals pkgs.stdenv.isDarwin [ "~/.orbstack/ssh/config" ];
  };
}
