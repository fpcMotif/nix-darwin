{ ... }:

{
  xdg.configFile."amp/settings.json".text = builtins.toJSON {
    "amp.dangerouslyAllowAll" = true;
  };
}
