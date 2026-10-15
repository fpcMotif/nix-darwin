{ config, lib, pkgs, currentSystemUser, currentSystemUserHome, ... }:

let
  cfg = config.martin.autoSwitch;
  logOut = "/var/log/nix-auto-switch.out.log";
  stateDir = "/var/lib/nix-auto-switch";
  flakeAttr = config.networking.localHostName;

  switchScript = pkgs.writeShellApplication {
    name = "martin-auto-switch";
    runtimeInputs = [ pkgs.git pkgs.nix pkgs.coreutils pkgs.gnutar ];
    text = ''
      # darwin-rebuild + the nix daemon tooling live on the system profile.
      export PATH="/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"

      repo=${lib.escapeShellArg cfg.repoPath}
      user=${lib.escapeShellArg currentSystemUser}
      state=${lib.escapeShellArg stateDir}
      attr=${lib.escapeShellArg flakeAttr}

      echo "=== $(date '+%Y-%m-%d %H:%M:%S') nix-auto-switch ==="
      mkdir -p "$state"

      if [ ! -d "$repo/.git" ]; then
        echo "no git repo at $repo; skip"; exit 0
      fi

      # Fetch as the repo owner: keeps .git objects user-owned and uses the
      # user's HOME/gitconfig (credential helper + http.sslCAInfo cert pin).
      if ! /usr/bin/sudo -H -u "$user" git -C "$repo" fetch --quiet origin main; then
        echo "fetch failed; skip"; exit 0
      fi

      rev=$(/usr/bin/sudo -H -u "$user" git -C "$repo" rev-parse origin/main || true)
      [ -n "$rev" ] || { echo "could not resolve origin/main; skip"; exit 0; }

      last=$(cat "$state/last-rev" 2>/dev/null || true)
      if [ "$rev" = "$last" ]; then
        echo "already applied origin/main=$rev; skip"; exit 0
      fi

      snapshot=$(mktemp -d "$state/snapshot.XXXXXX")
      cleanup() { rm -rf -- "$snapshot"; }
      trap cleanup EXIT INT TERM

      # Nix runs below as root. Feeding it the user-owned Git checkout makes
      # libgit2 reject the repo. Archive the exact fetched revision instead.
      if ! /usr/bin/sudo -H -u "$user" git -C "$repo" archive --format=tar "$rev" \
           | tar -xf - -C "$snapshot"; then
        echo "could not archive origin/main=$rev; skip"; exit 1
      fi

      echo "switching $attr to origin/main $rev from archived snapshot"
      if darwin-rebuild switch \
           --flake "$snapshot#$attr"; then
        printf '%s\n' "$rev" > "$state/last-rev"
        echo "switch OK -> $rev"
      else
        echo "switch FAILED for $rev (will retry next run)"
        exit 1
      fi
    '';
  };
in
{
  options.martin.autoSwitch = {
    enable = lib.mkEnableOption "unattended darwin-rebuild switch to latest origin/main";

    repoPath = lib.mkOption {
      type = lib.types.str;
      default = "${currentSystemUserHome}/nix-config";
      description = "Path to the local nix-config checkout whose origin/main is tracked.";
    };

    hour = lib.mkOption {
      type = lib.types.ints.between 0 23;
      default = 4;
      description = "Hour of day to run the unattended switch (local time).";
    };

    minute = lib.mkOption {
      type = lib.types.ints.between 0 59;
      default = 30;
      description = "Minute of hour to run the unattended switch.";
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.daemons.nix-auto-switch.serviceConfig = {
      ProgramArguments = [ (lib.getExe switchScript) ];
      # A switch reloads launchd daemons, so RunAtLoad = true would recurse.
      RunAtLoad = false;
      StartCalendarInterval = [{
        Hour = cfg.hour;
        Minute = cfg.minute;
      }];
      StandardOutPath = logOut;
      StandardErrorPath = logOut;
    };
  };
}
