{ pkgs, lib, config, ... }:

let
  routing = import ../shared/agent-model-routing.nix { inherit lib; };
  policy = pkgs.writeText "agent-model-routing.json" (builtins.toJSON routing.policy);
  python = pkgs.python3.withPackages (pythonPackages: [ pythonPackages.pyyaml ]);
in
{
  # Pi and OMP own mutable runtime settings. This adapter reasserts only model
  # routing fields from the shared semantic policy and preserves other state.
  home.activation.aiModelRouting = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${python}/bin/python3 ${./ai-model-routing.py} \
      ${policy} ${config.home.homeDirectory}
  '';
}
