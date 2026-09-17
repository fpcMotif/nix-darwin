{ lib, ... }:

let
  codexLsp = import ../shared/codex-lsp.nix { inherit lib; };
  modelRouting = import ../shared/agent-model-routing.nix { inherit lib; };
  codexEnvironment = modelRouting.adapters.codex.environment;
  codexDefaults = lib.replaceStrings
    [ "@PI_PLAN_MODEL@" "@PI_SLOW_MODEL@" "@PI_SMOL_MODEL@" ]
    [
      codexEnvironment.PI_PLAN_MODEL
      codexEnvironment.PI_SLOW_MODEL
      codexEnvironment.PI_SMOL_MODEL
    ]
    (builtins.readFile ../home/agent-instructions/codex/config.toml);
in
{
  # Codex loads this machine-wide layer below writable user overrides.
  # The desktop app can therefore persist model and reasoning choices in
  # ~/.codex/config.toml without losing the Nix-managed defaults and LSPs.
  environment.etc."codex/config.toml".text =
    codexDefaults + codexLsp.toml;
}
