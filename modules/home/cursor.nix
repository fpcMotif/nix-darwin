{ lib, pkgs, ... }:

let

  # Cursor writes to settings.json by renaming a temp file over the target,
  # which fails on a read-only store symlink. Copy this template on activation.
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

  # Gate on Darwin so Linux hosts do not grow a ~/Library tree.
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
