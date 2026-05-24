{ config, lib, pkgs, currentSystemUser, currentSystemUserHome, ... }:

let
  cfg = config.martin.healthCheck;
  logDir = "${currentSystemUserHome}/Library/Logs/nix-managed-health";

  reportScript = pkgs.writeShellApplication {
    name = "martin-macos-health-report";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnused
    ];
    text = ''
      log_dir="${logDir}"
      mkdir -p "$log_dir"

      latest="$log_dir/macos-health-latest.txt"
      dated="$log_dir/macos-health-$(date +%F).txt"
      tmp="$(mktemp "$log_dir/.macos-health.XXXXXX")"

      section() {
        printf '\n## %s\n' "$1"
      }

      {
        printf '# macOS health report\n'
        printf 'Generated: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
        printf 'Host: %s\n' "$(/bin/hostname)"

        section "System"
        /usr/bin/sw_vers 2>&1 || true
        /usr/bin/uname -a 2>&1 || true
        /usr/bin/uptime 2>&1 || true

        section "Disk Free"
        /bin/df -h / /System/Volumes/Data /nix 2>&1 || true

        section "Memory And Swap"
        /usr/sbin/sysctl vm.swapusage 2>&1 || true
        /usr/bin/memory_pressure 2>&1 | sed -n '1,90p' || true

        section "Time Machine"
        /usr/bin/tmutil status 2>&1 | sed -n '1,80p' || true
        /usr/bin/tmutil destinationinfo 2>&1 | sed -n '1,120p' || true
        latest_backup="$(/usr/bin/tmutil latestbackup 2>&1 || true)"
        printf 'Latest backup: %s\n' "$latest_backup"

        section "Nix GC Dry Run"
        ${lib.getExe pkgs.nix} store gc --dry-run 2>&1 | sed -n '1,160p' || true

        section "Diagnostic Report Families"
        ${lib.getExe pkgs.fd} -t f 'panic|\.panic$|\.ips$|\.crash$|\.diag$' \
          /Library/Logs/DiagnosticReports \
          "$HOME/Library/Logs/DiagnosticReports" 2>/dev/null \
          | awk -F/ '{print $NF}' \
          | sed -E 's/_[0-9]{4}-.*//; s/-[0-9]{4}-.*//; s/\.cpu_resource\.diag$//; s/\.diag$//; s/\.ips$//; s/\.crash$//' \
          | sort \
          | uniq -c \
          | sort -nr \
          | sed -n '1,40p' || true
      } > "$tmp"

      mv "$tmp" "$latest"
      cp "$latest" "$dated"
    '';
  };
in
{
  options.martin.healthCheck = {
    enable = lib.mkEnableOption "daily best-effort Nix-managed macOS health report";

    hour = lib.mkOption {
      type = lib.types.ints.between 0 23;
      default = 9;
      description = "Hour of day for the daily health report LaunchAgent.";
    };

    minute = lib.mkOption {
      type = lib.types.ints.between 0 59;
      default = 15;
      description = "Minute of hour for the daily health report LaunchAgent.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ reportScript ];

    system.activationScripts.postActivation.text = lib.mkAfter ''
      health_log_dir=${lib.escapeShellArg logDir}
      user_group="$(/usr/bin/id -gn ${lib.escapeShellArg currentSystemUser} 2>/dev/null || true)"

      if [ -z "$user_group" ]; then
        user_group=staff
      fi

      /bin/mkdir -p "$health_log_dir"
      /usr/sbin/chown ${lib.escapeShellArg currentSystemUser}:"$user_group" "$health_log_dir" 2>/dev/null || true
      /bin/chmod 0755 "$health_log_dir" 2>/dev/null || true
    '';

    home-manager.users.${currentSystemUser}.launchd.agents.macos-health-report = {
      enable = true;
      config = {
        ProgramArguments = [ (lib.getExe reportScript) ];
        RunAtLoad = true;
        StartCalendarInterval = {
          Hour = cfg.hour;
          Minute = cfg.minute;
        };
        StandardErrorPath = "${logDir}/launchd.stderr.log";
        StandardOutPath = "${logDir}/launchd.stdout.log";
      };
    };
  };
}
