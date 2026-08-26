{ lib, ... }:

{
  security.pam.services.sudo_local.touchIdAuth = true;

  networking.applicationFirewall = {
    enable = true;
    enableStealthMode = true;
    allowSigned = true;
    allowSignedApp = true;
    blockAllIncoming = false;
  };

  system.defaults.LaunchServices.LSQuarantine = true;

  # 🛡️ Sentinel: require the password immediately when the screensaver or
  # display sleep kicks in, instead of leaving an unlocked window.
  system.defaults.screensaver = {
    askForPassword = true;
    askForPasswordDelay = 0;
  };

  system.activationScripts.postActivation.text = lib.mkAfter ''
    if /usr/sbin/spctl --status 2>/dev/null | /usr/bin/grep -q 'disabled'; then
      /usr/sbin/spctl --master-enable || true
    fi
  '';
}
