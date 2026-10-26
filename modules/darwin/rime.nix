{ config, inputs, lib, pkgs, currentSystemUser, currentSystemUserHome, ... }:

let
  cfg = config.martin.rime;
  hmDag = inputs.home-manager.lib.hm.dag;
  rimeConfigSource = toString cfg.config;
in
{
  options.martin.rime = {
    enable = lib.mkEnableOption "Squirrel (Rime) input method with the rime-frost schema bundle";

    config = lib.mkOption {
      type = lib.types.either lib.types.path lib.types.str;
      description = ''
        Path to my Rime overrides (*.custom.yaml, squirrel.yaml). Its sync/
        subdirectory becomes Rime's sync_dir.
      '';
    };

    schemaSource = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../../pkgs/rime-frost.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ../../pkgs/rime-frost.nix { }";
      description = "Schema tree mirrored into ~/Library/Rime on every switch.";
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

    # Ship the pinned rime-frost tree plus my overrides to ~/Library/Rime via
    # Home Manager, then ask Squirrel to redeploy. Runs every switch.
    home-manager.users.${currentSystemUser} = {
      home.activation.rimeUserConfig = hmDag.entryAfter [ "writeBoundary" ] ''
        rime_dir="${currentSystemUserHome}/Library/Rime"
        echo "[rime] syncing rime-frost and ${rimeConfigSource} overrides into ~/Library/Rime"
        run mkdir -p "$rime_dir"

        if [ ! -d "${rimeConfigSource}" ]; then
          echo "[rime] ERROR: config source not found: ${rimeConfigSource}" >&2
          echo "[rime] set martin.rime.config to a directory that exists" >&2
          exit 1
        fi

        # Excluded paths are also protected from --delete: they hold learned
        # words, Squirrel state, and my overrides, which the schema tree must not clobber.
        run ${pkgs.rsync}/bin/rsync -a --delete \
          --chmod=Du+rwx,Dgo+rx,Fu+rw,Fgo+r \
          --exclude '.DS_Store' \
          --exclude '.git' \
          --exclude 'build/' \
          --exclude 'trash/' \
          --exclude '*.userdb/' \
          --exclude '*.userdb.txt' \
          --exclude 'sync/' \
          --exclude 'installation.yaml' \
          --exclude 'user.yaml' \
          --exclude '*.custom.yaml' \
          --exclude 'squirrel.yaml' \
          "${cfg.schemaSource}/" "$rime_dir/"

        for override in "${rimeConfigSource}"/*.custom.yaml "${rimeConfigSource}/squirrel.yaml"; do
          if [ -f "$override" ]; then run install -m 0644 "$override" "$rime_dir/"; fi
        done

        ensure_sync_dir() {
          installation="$rime_dir/installation.yaml"
          if [ -f "$installation" ] && ! grep -q '^sync_dir:' "$installation"; then
            echo "[rime] pointing Rime sync_dir at ${rimeConfigSource}/sync"
            # installation.yaml may lack a trailing newline.
            run sh -c 'printf "\nsync_dir: \"%s\"\n" "$1" >> "$2"' _ "${rimeConfigSource}/sync" "$installation"
          fi
        }
        ensure_sync_dir

        if [ -x "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel" ]; then
          squirrel="/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel"
          echo "[rime] registering and redeploying Squirrel"
          run "$squirrel" --register-input-source || true
          run "$squirrel" --enable-input-source || true
          run "$squirrel" --reload || true
        fi
        # A fresh install only gets installation.yaml after the first deploy.
        ensure_sync_dir
      '';
    };
  };
}
