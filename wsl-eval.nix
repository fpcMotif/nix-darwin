let
  flake = builtins.getFlake (toString ./.);
in
  flake.nixosConfigurations.wsl.config.system.build.toplevel
