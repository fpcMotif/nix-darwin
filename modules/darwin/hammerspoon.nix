{ config, lib, pkgs, currentSystemUser, ... }:

let
  cfg = config.martin.hammerspoon;
  appName = "Hammerspoon.app";
  hsPkg = pkgs.martin.hammerspoon;
  lsregister = "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister";

  defaultInit = ''
    -- Hammerspoon is reserved for rich macOS automation.
    -- skhd owned the small, fast global hotkey layer; it is off since
    -- 2026-07-19 over a BetterMouse event-tap conflict. See HOTKEYS.md.
    -- Current Hammerspoon uses Lua 5.4, not LuaJIT.

    local function notify(message)
      hs.alert.closeAll()
      hs.alert.show(message, 0.8)
    end

    local function launchOrFocus(appName)
      hs.application.launchOrFocus(appName)
    end

    local function bind(mods, key, fn)
      return hs.hotkey.bind(mods, key, fn)
    end

    local configDir = os.getenv("HOME") .. "/.hammerspoon/"
    local function reloadConfig(files)
      for _, file in ipairs(files) do
        if file:match("init%.lua$") then
          hs.reload()
          return
        end
      end
    end

    local configWatcher = hs.pathwatcher.new(configDir, reloadConfig)
    configWatcher:start()

    -- Keep helpers reachable for ad-hoc console experiments.
    _G.martin = {
      bind = bind,
      launchOrFocus = launchOrFocus,
      notify = notify,
    }

    notify("Hammerspoon loaded")
  '';
in
{
  options.martin.hammerspoon = {
    enable = lib.mkEnableOption "Hammerspoon macOS automation with a managed init.lua";

    extraInit = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Lua appended to ~/.hammerspoon/init.lua after the defaults.";
      example = ''
        hs.hotkey.bind({ "ctrl", "alt", "shift" }, "o", function()
          hs.application.launchOrFocus("Obsidian")
        end)
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Expose the `hs` CLI wrapper in system packages while keeping
    # /Applications out of this derivation. If a package in environment.systemPackages
    # outputs /Applications, nix-darwin's applications.nix rsyncs it into
    # /Applications/Nix Apps with `--chmod=-w`, which triggers nix-darwin's
    # `ensureAppManagement` check and fatally wedges the unattended nightly
    # auto-switch daemon (`error: permission denied when trying to update apps over SSH`).
    # Instead, we copy Hammerspoon.app into /Applications directly in postActivation,
    # identical to how Zed Nightly and Squirrel are deployed.
    environment.systemPackages = [
      (pkgs.runCommand "hammerspoon" {
        inherit (hsPkg) meta;
        passthru.app = hsPkg;
      } ''
        mkdir -p $out/bin
        cat << 'EOF' > $out/bin/hs
        #!/bin/sh
        exec /Applications/Hammerspoon.app/Contents/Frameworks/hs/hs "$@"
        EOF
        chmod +x $out/bin/hs
      '')
    ];

    system.activationScripts.postActivation.text = lib.mkAfter ''
      hs_src="${hsPkg}/Applications/${appName}"
      hs_dst="/Applications/${appName}"
      hs_marker="/Applications/.hammerspoon.src"

      if [ ! -d "$hs_src" ]; then
        echo "[hammerspoon] WARNING: $hs_src not found; skipping /Applications install" >&2
      elif [ "$(readlink "$hs_marker" 2>/dev/null)" != "${hsPkg}" ]; then
        echo "[hammerspoon] installing $hs_src into /Applications"
        if [ -e "$hs_dst" ]; then chmod -R u+w "$hs_dst" 2>/dev/null || true; fi
        rm -rf "$hs_dst"
        cp -R "$hs_src" "$hs_dst"
        chmod -R u+w "$hs_dst"
        ln -sfn "${hsPkg}" "$hs_marker"
        echo "[hammerspoon] registering $hs_dst with LaunchServices"
        ${lsregister} -f "$hs_dst" || true
      fi
    '';

    home-manager.users.${currentSystemUser} = {
      home.file.".hammerspoon/init.lua".text = defaultInit + cfg.extraInit;
    };
  };
}
