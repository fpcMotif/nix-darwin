{ config, lib, pkgs, currentSystemUser, currentSystemUserHome, ... }:

# Unattended `darwin-rebuild switch` to the latest origin/main. The hourly
# auto-update workflow keeps origin/main current; this daemon is what actually
# lands those bumps on THIS machine without a manual `just switch`.
#
# Safety model:
#   * Builds straight from `refs/remotes/origin/main` (a pinned rev), so the
#     local working tree is never touched — no merge, no clobber of uncommitted
#     work or local-only commits, no fight with the autoresearch loop.
#   * `git fetch` runs as the repo owner (keeps .git user-owned and reuses the
#     user's gitconfig, incl. the http.sslCAInfo cert pin); only the rebuild
#     runs as root.
#   * A last-applied-rev marker makes a run a no-op when origin hasn't moved.
#   * RunAtLoad = false: a switch reloads launchd daemons, so running at load
#     would recurse. The calendar interval is the only trigger.
let
  cfg = config.martin.autoSwitch;
  logOut = "/var/log/nix-auto-switch.out.log";
  stateDir = "/var/lib/nix-auto-switch";
  flakeAttr = config.networking.localHostName;

  switchScript = pkgs.writeShellApplication {
    name = "martin-auto-switch";
    runtimeInputs = [ pkgs.git pkgs.nix pkgs.coreutils ];
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

      echo "switching $attr to origin/main $rev"
      if darwin-rebuild switch \
           --flake "git+file://$repo?ref=refs/remotes/origin/main&rev=$rev#$attr"; then
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
