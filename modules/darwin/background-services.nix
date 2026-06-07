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

in
{
  options.martin.backgroundServices = {
    cleanMyMacManualOnly =
      lib.mkEnableOption "manual-only CleanMyMac by disabling its launchd helpers";
  };

  config = {
    martin.darwinBaseline.activationState.launchdDisabledDomains =
      cleanMyMacEntries;
  };
}
