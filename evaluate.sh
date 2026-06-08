#!/bin/bash
export PATH=$PATH:/nix/var/nix/profiles/default/bin
nix-instantiate --eval --expr '
let
  flake = builtins.getFlake (toString ./.);
in
  (builtins.tryEval flake.nixosConfigurations.wsl.config.system.build.toplevel.drvPath).success
'
