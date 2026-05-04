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
  };

  config = lib.mkIf cfg.enable {
    # Squirrel.app belongs in /Library/Input Methods. nix-darwin's
    # `system.activationScripts.applications` only links *.app from
    # environment.systemPackages into /Applications, so we install
    # Squirrel.app into /Library/Input Methods explicitly.
    environment.systemPackages = [ pkgs.martin.squirrel ];

    # nix-darwin only runs a fixed list of activation script names; arbitrary
    # keys are silently dropped. We piggy-back on `postActivation` so Squirrel
    # is on disk before the per-user `home.activation.rimeUserConfig` step
    # tries to talk to it.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      input_methods_dir="/Library/Input Methods"
      target="$input_methods_dir/Squirrel.app"
      source="${pkgs.martin.squirrel}/Library/Input Methods/Squirrel.app"

      mkdir -p "$input_methods_dir"

      # Idempotent: if the symlink already points at the current store path,
      # don't churn the inode (breaks watchers and is a no-op anyway).
      if [ "$(readlink "$target" 2>/dev/null)" != "$source" ]; then
        echo "[rime] linking Squirrel.app into /Library/Input Methods"
        if [ -e "$target" ] && [ ! -L "$target" ]; then
          backup="$target.backup-before-nix"
          if [ -e "$backup" ]; then
            backup="$target.backup-before-nix-$(/bin/date +%Y%m%d%H%M%S)"
          fi
          mv "$target" "$backup"
        fi
        rm -f "$target"
        ln -s "$source" "$target"
      fi
    '';

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
          "${rimeConfigSource}/" "${currentSystemUserHome}/Library/Rime/"

        if [ -x "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel" ]; then
          echo "[rime] redeploying Squirrel"
          run "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel" --reload || true
        fi
      '';
    };
  };
}
