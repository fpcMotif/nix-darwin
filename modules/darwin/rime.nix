{ config, inputs, lib, pkgs, currentSystemUser, currentSystemUserHome, ... }:

let
  cfg = config.martin.rime;
  hmDag = inputs.home-manager.lib.hm.dag;
  rimeConfigSource = toString cfg.config;
in
{
  options.martin.rime = {
    enable = lib.mkEnableOption "Squirrel (Rime) input method with the MyRime-main schema bundle";

    config = lib.mkOption {
      type = lib.types.either lib.types.path lib.types.str;
      description = "Path to the Rime user-config directory (the directory copied into ~/Library/Rime).";
    };

    manageApp = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether nix-darwin installs/overwrites Squirrel.app in /Library/Input
        Methods from `pkgs.martin.squirrel`. Disable when Squirrel.app is
        managed manually instead (e.g. a patched fork built outside nix) so
        `darwin-rebuild switch` never clobbers it. The Rime config sync and
        `--reload` still run either way.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Gate on manageApp so a manually built Squirrel fork is not shadowed by a
    # second copy in /Applications.
    environment.systemPackages = lib.optionals cfg.manageApp [ pkgs.martin.squirrel ];

    # nix-darwin ignores custom activation script names, and Squirrel must exist
    # in /Library/Input Methods before home.activation.rimeUserConfig reloads it.
    system.activationScripts.postActivation.text = lib.mkAfter (lib.optionalString cfg.manageApp ''
      input_methods_dir="/Library/Input Methods"
      target="$input_methods_dir/Squirrel.app"
      source="${pkgs.martin.squirrel}/Library/Input Methods/Squirrel.app"
      source_marker="$input_methods_dir/.Squirrel.app.nix-source"

      mkdir -p "$input_methods_dir"

      installed_source="$(cat "$source_marker" 2>/dev/null || true)"
      if [ "$installed_source" != "$source" ] || [ -L "$target" ] || [ ! -d "$target" ]; then
        echo "[rime] copying Squirrel.app into /Library/Input Methods"
        if [ -e "$target" ] && [ ! -L "$target" ] && [ ! -e "$source_marker" ]; then
          backup="$target.backup-before-nix"
          if [ -e "$backup" ]; then
            backup="$target.backup-before-nix-$(/bin/date +%Y%m%d%H%M%S)"
          fi
          mv "$target" "$backup"
        else
          rm -rf "$target"
        fi
        /usr/bin/ditto "$source" "$target"
        printf '%s\n' "$source" > "$source_marker"
      fi
    '');

    # Ship the MyRime-main schema/config tree to ~/Library/Rime via Home Manager,
    # then ask Squirrel to redeploy. Activation runs every switch so config edits land.
    home-manager.users.${currentSystemUser} = {
      home.activation.rimeUserConfig = hmDag.entryAfter [ "writeBoundary" ] ''
        echo "[rime] syncing MyRime-main into ~/Library/Rime"
        run mkdir -p "${currentSystemUserHome}/Library/Rime"

        if [ ! -d "${rimeConfigSource}" ]; then
          echo "[rime] ERROR: config source not found: ${rimeConfigSource}" >&2
          echo "[rime] set martin.rime.config to a directory that exists" >&2
          exit 1
        fi

        run ${pkgs.rsync}/bin/rsync -a --delete \
          --chmod=Du+rwx,Dgo+rx,Fu+rw,Fgo+r \
          --exclude '.DS_Store' \
          --exclude '.git' \
          --exclude 'build/' \
          --exclude '*.userdb/' \
          --exclude '*.userdb.txt' \
          --exclude 'sync/' \
          --exclude 'squirrel.yaml' \
          "${rimeConfigSource}/" "${currentSystemUserHome}/Library/Rime/"

        if [ -x "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel" ]; then
          squirrel="/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel"
          echo "[rime] registering and redeploying Squirrel"
          run "$squirrel" --register-input-source || true
          run "$squirrel" --enable-input-source || true
          run "$squirrel" --reload || true
        fi
      '';
    };
  };
}
