{ config, inputs, lib, pkgs, currentSystemUser, currentSystemUserHome, ... }:

let
  cfg = config.martin.mouseDisplay;
  hmDag = inputs.home-manager.lib.hm.dag;
  bettermouseSeed = "${currentSystemUserHome}/Library/Application Support/BetterMouse/bm_cfg.plist";
  appLogDir = "${currentSystemUserHome}/Library/Logs/nix-managed-apps";
  profileSource =
    if cfg.bettermouse.profile == null
    then ""
    else toString cfg.bettermouse.profile;
  lsregister = "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister";
in
{
  options.martin.mouseDisplay = {
    enable = lib.mkEnableOption "BetterMouse + BetterDisplay GUI apps with declarative seed config";

    bettermouse.profile = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
      default = null;
      description = ''
        Optional binary plist exported from BetterMouse (Preferences → Export). When set, the file
        is copied to ~/Library/Application Support/BetterMouse/ on activation as a one-shot seed.
        BetterMouse owns the file after first launch — touch the source to re-seed.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.martin.bettermouse
      pkgs.betterdisplay
    ];

    # Run BetterMouse/BetterDisplay from /Applications copies, never straight
    # from the store. macOS stamps any bundle the user grants Accessibility /
    # Input-Monitoring with a kernel `com.apple.macl` xattr; on a *store* path
    # that xattr makes the bundle undeletable even by root, so the weekly
    # `nix.gc` aborts on it (fchmodat: Operation not permitted) and then stops
    # collecting *anything* — every old version piles up forever. Copying to
    # /Applications (writable, outside the store) keeps the store path clean and
    # GC-able — same trick as modules/darwin/zed.nix. `xattr -rc` before re-copy
    # defuses any macl already on the previous /Applications copy so version
    # bumps don't get stuck.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      install_managed_app() {
        local src="$1" dst="$2" marker="$3" pkg="$4"
        if [ ! -d "$src" ]; then
          echo "[mouse-display] WARNING: $src not found; skipping /Applications install" >&2
        elif [ "$(readlink "$marker" 2>/dev/null)" != "$pkg" ]; then
          echo "[mouse-display] installing $src into /Applications"
          if [ -e "$dst" ]; then
            xattr -rc "$dst" 2>/dev/null || true
            chmod -R u+w "$dst" 2>/dev/null || true
          fi
          rm -rf "$dst"
          cp -R "$src" "$dst"
          chmod -R u+w "$dst"
          ln -sfn "$pkg" "$marker"
          ${lsregister} -f "$dst" || true
        fi
      }
      install_managed_app "${pkgs.martin.bettermouse}/Applications/BetterMouse.app" "/Applications/BetterMouse.app" "/Applications/.bettermouse.src" "${pkgs.martin.bettermouse}"
      install_managed_app "${pkgs.betterdisplay}/Applications/BetterDisplay.app" "/Applications/BetterDisplay.app" "/Applications/.betterdisplay.src" "${pkgs.betterdisplay}"
    '';

    home-manager.users.${currentSystemUser} = {
      home.activation.bettermouseSeed = hmDag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p "${appLogDir}"

        if [ -n "${profileSource}" ]; then
          seed_dir="${currentSystemUserHome}/Library/Application Support/BetterMouse"
          stamp="$seed_dir/.nix-seed-source"
          src="${profileSource}"

          run mkdir -p "$seed_dir"

          if [ ! -f "$src" ]; then
            echo "[bettermouse] profile source not found: $src" >&2
          elif [ ! -f "$stamp" ] || [ "$(cat "$stamp" 2>/dev/null)" != "$src" ]; then
            echo "[bettermouse] seeding profile from $src"
            run install -m 0644 "$src" "${bettermouseSeed}"
            printf %s "$src" > "$stamp"
          fi
        fi
      '';

      launchd.agents = {
        betterdisplay = {
          enable = true;
          config = {
            ProgramArguments = [
              "/usr/bin/open"
              "-g"
              "/Applications/BetterDisplay.app"
            ];
            ProcessType = "Interactive";
            RunAtLoad = true;
            StandardErrorPath = "${appLogDir}/betterdisplay.stderr.log";
            StandardOutPath = "${appLogDir}/betterdisplay.stdout.log";
          };
        };

        bettermouse = {
          enable = true;
          config = {
            ProgramArguments = [
              "/usr/bin/open"
              "-g"
              "/Applications/BetterMouse.app"
            ] ++ lib.optionals (cfg.bettermouse.profile != null) [
              "--args"
              bettermouseSeed
            ];
            ProcessType = "Interactive";
            RunAtLoad = true;
            StandardErrorPath = "${appLogDir}/bettermouse.stderr.log";
            StandardOutPath = "${appLogDir}/bettermouse.stdout.log";
          };
        };
      };
    };
  };
}
