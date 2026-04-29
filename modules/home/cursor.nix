{ lib, ... }:

let
  cursorExtensions = [
    "esbenp.prettier-vscode"
    "ms-python.python"
  ];
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

    ".config/Cursor/User/settings.json" = {
      text = builtins.toJSON {
        "extensions.autoCheckUpdates" = false;
        "extensions.autoUpdate" = false;
        "telemetry.telemetryLevel" = "off";
        "editor.formatOnSave" = true;
        "workbench.editor.enablePreview" = false;
      };
    };
  };

  home.activation.cursorSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/Library/Application Support/Cursor/User"
    ln -sf "$HOME/.config/Cursor/User/settings.json" \
      "$HOME/Library/Application Support/Cursor/User/settings.json"
  '';

  home.activation.cursorExtensions =
    let
      extensionArgs = lib.concatMapStringsSep " " lib.escapeShellArg cursorExtensions;
    in
    lib.hm.dag.entryAfter [ "cursorSettings" ] ''
      cursor_cmd=""
      if command -v cursor >/dev/null 2>&1; then
        cursor_cmd="$(command -v cursor)"
      elif [ -x "/Applications/Cursor.app/Contents/Resources/app/bin/cursor" ]; then
        cursor_cmd="/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
      fi

      if [ -z "$cursor_cmd" ]; then
        echo "Cursor CLI not available, skipping extension sync."
        exit 0
      fi

      for ext in ${extensionArgs}; do
        if ! "$cursor_cmd" --install-extension "$ext" --force; then
          echo "Cursor extension '$ext' could not be installed; continuing." >&2
        fi
      done
    '';
}
