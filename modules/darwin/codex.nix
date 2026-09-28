{ config, lib, pkgs, currentSystemUser, ... }:

let
  docLock = config.home-manager.users.${currentSystemUser}.martin.development.docLock;
  docLockExe = lib.getExe pkgs.martin.doc-lock;
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

  environment.etc."codex/requirements.toml" = lib.mkIf docLock {
    text = ''
      [[hooks.UserPromptSubmit]]
      [[hooks.UserPromptSubmit.hooks]]
      type = "command"
      command = "${docLockExe} grant"

      [[hooks.PreToolUse]]
      matcher = "^apply_patch$"
      [[hooks.PreToolUse.hooks]]
      type = "command"
      command = "${docLockExe} edit"
    '';
  };
}
