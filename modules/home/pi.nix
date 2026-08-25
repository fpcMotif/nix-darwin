{ lib, pkgs, currentSystemUserHome, ... }:

let
  updater = pkgs.writeShellApplication {
    name = "pi-update-extensions";
    runtimeInputs = [
      pkgs.martin.pi-coding-agent
      pkgs.martin.bun-canary-bin
      pkgs.git
      pkgs.cacert
    ];
    text = ''
      export HOME=${lib.escapeShellArg currentSystemUserHome}
      export PATH="$PATH:/usr/bin:/bin:/usr/sbin:/sbin"
      export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

      echo "=== $(date '+%Y-%m-%d %H:%M:%S') pi extension update ==="
      pi update --extensions --no-approve
    '';
  };
in
{
  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    launchd.agents.pi-extension-update = {
      enable = true;
      config = {
        ProgramArguments = [ (lib.getExe updater) ];
        StartCalendarInterval = {
          Hour = 6;
          Minute = 15;
        };
        RunAtLoad = false;
        ProcessType = "Background";
        LowPriorityIO = true;
        StandardOutPath = "${currentSystemUserHome}/Library/Logs/pi-extension-update.log";
        StandardErrorPath = "${currentSystemUserHome}/Library/Logs/pi-extension-update.log";
      };
    };
  };
}
