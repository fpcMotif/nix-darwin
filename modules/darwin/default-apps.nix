{ lib, pkgs, ... }:

# IINA is the preferred video player, but macOS/App updates keep re-claiming
# video UTIs for QuickTime Player (or whichever app installs most recently).
# Re-assert IINA as the LaunchServices default opener for every common video
# container format on every activation, via `duti` (already carried in
# environment.systemPackages, hosts/darwin/default.nix).
#
# `.ts` is deliberately excluded: it collides with TypeScript source files,
# which must keep opening in the editor, not IINA.

let
  duti = lib.getExe pkgs.duti;
  iina = "com.colliderli.iina";
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
  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo "[default-apps] setting IINA as default video player"
    # `duti -s` talks to LaunchServices/cfprefsd; firing calls back-to-back with
    # no gap silently drops all but the first few writes, so pace the loop.
    ${lib.concatMapStringsSep "\n    " (
      ext: ''${duti} -s ${iina} .${ext} all >/dev/null 2>&1 || true; sleep 0.15''
    ) videoExtensions}
    ${duti} -s ${iina} public.movie all >/dev/null 2>&1 || true
  '';
}
