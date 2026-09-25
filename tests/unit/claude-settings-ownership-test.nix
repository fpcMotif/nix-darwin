{ pkgs, lib, ... }:

let
  seedSettings = {
    model = "opus";
    env = { API_TIMEOUT_MS = "3000000"; };
    permissions = {
      allow = [ "Bash(nix *)" ];
      deny = [ "Read(~/.ssh/**)" ];
      ask = [ "Read(~/Downloads/**)" ];
      defaultMode = "bypassPermissions";
    };
    enabledPlugins = {
      "parked@official" = true;
      "kept@official" = true;
    };
    hooks.PreToolUse = [
      {
        matcher = "Read";
        hooks = [{ type = "command"; command = "$HOME/.claude/hooks/read-guard.sh"; }];
      }
    ];
    autoMemoryEnabled = false;
    autoDreamEnabled = false;
    worktree = { symlinkDirectories = [ "node_modules" ".cache" ]; };
  };
  seed = pkgs.writeText "claude-settings-ownership-seed.json" (builtins.toJSON seedSettings);
  basePolicy = {
    own = [
      { path = [ "permissions" "allow" ]; value = [ "Bash(nix *)" ]; }
      { path = [ "permissions" "deny" ]; value = [ "Read(~/.ssh/**)" ]; }
      { path = [ "permissions" "ask" ]; value = [ "Read(~/Downloads/**)" ]; }
      { path = [ "permissions" "defaultMode" ]; value = "bypassPermissions"; }
      { path = [ "skillOverrides" "duplicate-skill" ]; value = "off"; }
      { path = [ "enabledPlugins" "parked@official" ]; value = false; }
      { path = [ "autoMemoryEnabled" ]; value = false; }
      { path = [ "autoDreamEnabled" ]; value = false; }
      { path = [ "worktree" "symlinkDirectories" ]; value = [ "node_modules" ".cache" ]; }
    ];
    default = [
      { path = [ "env" "API_TIMEOUT_MS" ]; value = "3000000"; }
      { path = [ "env" "MISSING_DEFAULT" ]; value = "filled-by-nix"; }
      { path = [ "env" "NULL_DEFAULT" ]; value = "not-null"; }
      { path = [ "env" "FALSE_DEFAULT" ]; value = "not-false"; }
    ];
    add = [
      {
        event = "PreToolUse";
        matcher = "Bash";
        command = "$HOME/.claude/hooks/shell-guard.sh";
      }
      {
        event = "PostToolUse";
        matcher = "Edit";
        command = "$HOME/.claude/hooks/edit-batch-nudge.sh";
      }
    ];
  };
  oldPolicy = basePolicy // {
    own = basePolicy.own ++ [
      { path = [ "skillOverrides" "retired-unchanged" ]; value = "off"; }
      { path = [ "skillOverrides" "retired-edited" ]; value = "off"; }
    ];
  };
  retiredSeedPolicy = basePolicy // {
    own = builtins.filter (entry: entry.path != [ "autoMemoryEnabled" ]) basePolicy.own;
  };
  # The production marker list, selected the way claude.nix selects it.
  backendPolicy = worktrunkEnabled:
    let
      markers = import ../../modules/home/claude/worktrunk-markers.nix {
        inherit lib;
        enable = worktrunkEnabled;
      };
    in
    basePolicy // {
      add = basePolicy.add ++ markers.add;
      inherit (markers) remove;
    };
  mkOwnership = policy:
    import ../../modules/home/claude/settings-ownership.nix {
      inherit pkgs policy seed;
    };
  current = mkOwnership basePolicy;
  old = mkOwnership oldPolicy;
  retiredSeed = mkOwnership retiredSeedPolicy;
  worktrunk = mkOwnership (backendPolicy true);
  dojjo = mkOwnership (backendPolicy false);
in
pkgs.runCommand "unit-claude-settings-ownership"
{ nativeBuildInputs = [ pkgs.bash pkgs.jq pkgs.coreutils pkgs.diffutils ]; }
  ''
    ${pkgs.bash}/bin/bash ${./claude-settings-ownership-test.sh} \
      ${current.command}/bin/claude-settings-ownership \
      ${old.command}/bin/claude-settings-ownership \
      ${current.command}/bin/claude-settings-ownership \
      ${retiredSeed.command}/bin/claude-settings-ownership \
      ${worktrunk.command}/bin/claude-settings-ownership \
      ${dojjo.command}/bin/claude-settings-ownership
    touch $out
  ''
