{ lib, pkgs, ... }:

# Conductor — and Spotlight, `open`, and any LaunchServices-driven "open in
# editor" feature — discovers editors as registered .app bundles in
# /Applications. Zed is Home-Manager-managed (programs.zed-editor ->
# pkgs.martin.zed-nightly-bin), so its only bundle lives in the nix store,
# surfaced merely as a *symlink* under ~/Applications/Home Manager Apps whose
# target store path changes on every nightly bump. LaunchServices then caches a
# stale, garbage-collected store path and apps like Conductor can no longer
# launch Zed.
#
# Modeled on modules/darwin/rime.nix's Squirrel install: place the current
# bundle in /Applications on every activation and re-register it. We *copy*
# rather than symlink so `open`/Gatekeeper treat it as an ordinary installed app
# (symlinked bundles hit app-translocation edge cases). The hidden
# `/Applications/.zed-nightly.src` marker points at the active store path, which
# keeps the copy idempotent — it only re-copies when that path actually changes.

let
  zedPkg = pkgs.martin.zed-nightly-bin;
  appName = "Zed Nightly.app";
  lsregister = "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister";
in
{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    zed_src="${zedPkg}/Applications/${appName}"
    zed_dst="/Applications/${appName}"
    zed_marker="/Applications/.zed-nightly.src"

    if [ ! -d "$zed_src" ]; then
      echo "[zed] WARNING: $zed_src not found; skipping /Applications install" >&2
    elif [ "$(readlink "$zed_marker" 2>/dev/null)" != "${zedPkg}" ]; then
      echo "[zed] installing $zed_src into /Applications"
      if [ -e "$zed_dst" ]; then chmod -R u+w "$zed_dst" 2>/dev/null || true; fi
      rm -rf "$zed_dst"
      cp -R "$zed_src" "$zed_dst"
      chmod -R u+w "$zed_dst"
      ln -sfn "${zedPkg}" "$zed_marker"
      echo "[zed] registering $zed_dst with LaunchServices"
      ${lsregister} -f "$zed_dst" || true
    fi
  '';
}
