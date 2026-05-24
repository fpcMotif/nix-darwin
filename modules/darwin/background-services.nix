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

  cleanMyMacEntries = lib.optionals cfg.cleanMyMacManualOnly [
    {
      name = "cleanmymac-user-helpers";
      domain = {
        kind = "gui";
        user = currentSystemUser;
      };
      labels = cleanMyMacUserLabels;
      reason = "manual-only app";
    }
    {
      name = "cleanmymac-system-helper";
      domain.kind = "system";
      labels = cleanMyMacSystemLabels;
      reason = "manual-only app";
    }
  ];

  dropboxEntries = lib.optionals cfg.dropbox.disableBackgroundUpdaters [
    {
      name = "dropbox-background-updaters";
      domain.kind = "system";
      labels = dropboxSystemLabels;
      reason = "background churn";
    }
  ];
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

    martin.darwinBaseline.activationState.launchdDisabledDomains =
      cleanMyMacEntries ++ dropboxEntries;
  };
}
