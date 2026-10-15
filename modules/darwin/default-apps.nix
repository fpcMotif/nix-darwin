{ inputs, lib, pkgs, currentSystemUser, ... }:

let
  duti = lib.getExe pkgs.duti;
  iina = "com.colliderli.iina";
  canary = "com.google.Chrome.canary";
  browserSchemes = [
    "http"
    "https"
  ];
  browserExtensions = [
    "html"
    "htm"
    "shtml"
    "xhtml"
  ];
  # Omit .ts so TypeScript source files keep opening in the editor.
  videoExtensions = [
    "mp4"
    "m4v"
    "mov"
    "qt"
    "avi"
    "wmv"
    "flv"
    "webm"
    "mkv"
    "mpg"
    "mpeg"
    "mpeg4"
    "m2v"
    "m2ts"
    "mts"
    "3gp"
    "3g2"
    "ogv"
    "ogm"
    "vob"
    "asf"
    "rm"
    "rmvb"
    "divx"
    "dv"
  ];
in
{
  # macOS and app updates reset video UTIs to QuickTime Player.
  home-manager.users.${currentSystemUser}.home.activation.defaultApps = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "[default-apps] setting IINA as default video player"
    # `duti -s` talks to LaunchServices/cfprefsd; firing calls back-to-back with
    # no gap silently drops all but the first few writes, so pace the loop.
    ${lib.concatMapStringsSep "\n    " (
      ext: ''${duti} -s ${iina} .${ext} all >/dev/null 2>&1 || true; sleep 0.15''
    ) videoExtensions}
    ${duti} -s ${iina} public.movie all >/dev/null 2>&1 || true
    echo "[default-apps] setting Chrome Canary as default browser"
    ${lib.concatMapStringsSep "\n    " (
      scheme: ''${duti} -s ${canary} ${scheme} >/dev/null 2>&1 || true; sleep 0.15''
    ) browserSchemes}
    ${lib.concatMapStringsSep "\n    " (
      ext: ''${duti} -s ${canary} .${ext} all >/dev/null 2>&1 || true; sleep 0.15''
    ) browserExtensions}
    ${duti} -s ${canary} public.html all >/dev/null 2>&1 || true
    ${duti} -s ${canary} public.xhtml all >/dev/null 2>&1 || true
  '';
}
