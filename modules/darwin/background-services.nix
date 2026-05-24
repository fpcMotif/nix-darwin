{ config, lib, pkgs, currentSystemUser, ... }:

let
  cfg = config.martin.backgroundServices;

  cleanMyMacUserLabels = [
    "com.macpaw.CleanMyMac5.HealthMonitor"
    "com.macpaw.CleanMyMac5.Menu"
    "com.macpaw.CleanMyMac5.Updater"
  ];

  cleanMyMacSystemLabels = [
    "com.macpaw.CleanMyMac5.Agent"
  ];

  dropboxSystemLabels = [
    "com.dropbox.DropboxUpdater.wake.system"
    "com.getdropbox.dropbox.UpdaterPrivilegedHelper"
  ];

  disableLabels = scope: labels: ''
    # shellcheck disable=SC2043
    for label in ${lib.escapeShellArgs labels}; do
      scope="${scope}"
      domain="$scope/$label"
      already_disabled=0

      if /bin/launchctl print-disabled "$scope" 2>/dev/null \
        | /usr/bin/grep -F "\"$label\" => true" >/dev/null; then
        already_disabled=1
      fi

      if /bin/launchctl disable "$domain" 2>/dev/null \
        && [ "$already_disabled" -eq 0 ]; then
        printf '%s\n' "$domain" >> "$next_state"
      fi

      /bin/launchctl bootout "$domain" 2>/dev/null || true
    done
  '';
in
{
  options.martin.backgroundServices = {
    cleanMyMacManualOnly =
      lib.mkEnableOption "manual-only CleanMyMac by disabling its launchd helpers";

    dropbox = {
      installClient =
        lib.mkEnableOption "Dropbox client installation as a baseline system app";

      disableBackgroundUpdaters =
        lib.mkEnableOption "Dropbox updater/helper launchd job suppression";
    };
  };

  config = {
    environment.systemPackages =
      lib.optionals cfg.dropbox.installClient [ pkgs.martin.dropbox ];

    system.activationScripts.postActivation.text = lib.mkAfter ''
      state_dir="/var/db/nix-config"
      state_file="$state_dir/background-services-disabled-by-nix"
      /bin/mkdir -p "$state_dir"
      next_state="$(/usr/bin/mktemp "$state_dir/.background-services.XXXXXX")"
      : > "$next_state"

      ${lib.optionalString cfg.cleanMyMacManualOnly ''
        user_uid="$(/usr/bin/id -u ${lib.escapeShellArg currentSystemUser} 2>/dev/null || true)"

        if [ -n "$user_uid" ]; then
          ${disableLabels "gui/$user_uid" cleanMyMacUserLabels}
        fi

        ${disableLabels "system" cleanMyMacSystemLabels}
      ''}
      ${lib.optionalString cfg.dropbox.disableBackgroundUpdaters (disableLabels "system" dropboxSystemLabels)}

      if [ -f "$state_file" ]; then
        while IFS= read -r domain; do
          if [ -n "$domain" ] && ! /usr/bin/grep -Fxq "$domain" "$next_state"; then
            /bin/launchctl enable "$domain" 2>/dev/null || true
          fi
        done < "$state_file"
      fi

      if [ -s "$next_state" ]; then
        /bin/mv "$next_state" "$state_file"
        /bin/chmod 0644 "$state_file" 2>/dev/null || true
      else
        /bin/rm -f "$state_file" "$next_state"
      fi
    '';
  };
}
