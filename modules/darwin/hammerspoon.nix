{ config, lib, pkgs, currentSystemUser, ... }:

let
  cfg = config.martin.hammerspoon;

  defaultInit = ''
    -- Hammerspoon is reserved for rich macOS automation.
    -- skhd owns the small, fast global hotkey layer.
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
    environment.systemPackages = [ pkgs.martin.hammerspoon ];

    home-manager.users.${currentSystemUser} = {
      home.file.".hammerspoon/init.lua".text = defaultInit + cfg.extraInit;
    };
  };
}
