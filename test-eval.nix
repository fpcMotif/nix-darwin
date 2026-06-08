let
  flake = builtins.getFlake (toString ./.);
  wsl = flake.nixosConfigurations.wsl;
in
  wsl.config.system.build.toplevel
