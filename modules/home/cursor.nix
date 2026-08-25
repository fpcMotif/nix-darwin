{ lib, pkgs, ... }:

let

  # Cursor (like all VS Code forks) writes back to its own settings.json:
  # UI toggles, and atomic saves that rename a temp file over the target.
  # A home.file entry would symlink this into the read-only nix store
  # (mode 0444), so Cursor's writes fail with EACCES / EntryWriteLocked.
  # Instead we render the defaults in the store and copy them into place as
  # a real, writable file during activation. Nix stays the source of truth
  # (defaults are reapplied on every switch) while Cursor can still save.
  cursorSettingsFile = pkgs.writeText "cursor-settings.json" (builtins.toJSON {
    "extensions.autoCheckUpdates" = false;
    "extensions.autoUpdate" = false;
    "telemetry.telemetryLevel" = "off";
    "editor.formatOnSave" = true;
    "workbench.editor.enablePreview" = false;
  });
in
{
  home.file = {
    ".local/bin/npm" = {
      text = ''
        #! /bin/sh
        exec bun "$@"
      '';
      executable = true;
    };

    ".local/bin/npx" = {
      text = ''
        #! /bin/sh
        exec bunx "$@"
      '';
      executable = true;
    };

    ".local/bin/pnpm" = {
      text = ''
        #! /bin/sh
        exec bun "$@"
      '';
      executable = true;
    };
  };

  # Cursor's settings live under macOS's ~/Library and its CLI ships inside
  # the .app bundle, so this whole sync is Darwin-only. A Linux host must not
  # grow a ~/Library tree; revisit with XDG paths if Cursor joins the Linux
  # profile.
  home.activation.cursorSettings = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cursorUserDir="$HOME/Library/Application Support/Cursor/User"
    mkdir -p "$cursorUserDir"

    # Replace any prior read-only store symlink (or stale file) with a real,
    # writable copy so Cursor can save changes back to it.
    rm -f "$cursorUserDir/settings.json"
    install -m 0644 ${cursorSettingsFile} "$cursorUserDir/settings.json"

    # Drop the legacy XDG symlink the old layout created; Cursor on macOS
    # reads the Library path directly, so the indirection is unneeded.
    if [ -L "$HOME/.config/Cursor/User/settings.json" ]; then
      rm -f "$HOME/.config/Cursor/User/settings.json"
    fi
  '');

}
