{ config, lib, pkgs, ... }:

let
  enabled = config.martin.development.docLock;
  docLockExe = lib.getExe pkgs.martin.doc-lock;
  hk = pkgs.martin.hk-bin;
  claudeHooks = [
    { event = "UserPromptSubmit"; matcher = ""; command = "$HOME/.claude/hooks/doc-lock.sh grant"; }
    { event = "PreToolUse"; matcher = "Edit|Write|MultiEdit"; command = "$HOME/.claude/hooks/doc-lock.sh edit"; }
  ];
in
{
  options.martin.development.docLock = lib.mkOption {
    type = lib.types.bool;
    default = true;
    example = false;
    description = ''
      Keep coding agents from changing comments and Markdown until the user
      asks for docs work in the session (pkgs/doc-lock.nix).

      On, it wires the edit gate into every agent: Claude Code hooks, Codex
      managed hooks (/etc/codex/requirements.toml), and one extension that
      pi and omp both load. It also adds the user-level hk pre-commit step
      and the "Docs lock" section of every agent guide. Set it false to roll
      all of it back on the next switch. To switch the lock off without a
      rebuild, start the agent with DOC_LOCK_OFF=1 in its environment.
    '';
  };

  config = lib.mkMerge [
    # Off, the reconciler strips these exact entries from the live settings.json.
    { martin.agentSurface.claudeHooks.${if enabled then "add" else "remove"} = claudeHooks; }

    (lib.mkIf enabled {
      martin.agentSurface.guideSections.startup = [ ./guide.md ];

      martin.agentSurface.codexRequirements = ''
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

      home.file.".claude/hooks/doc-lock.sh".source = docLockExe;
      home.file.".pi/agent/extensions/doc-lock.ts".source = pkgs.martin.doc-lock-extension;
      home.file.".omp/agent/hooks/pre/doc-lock.ts".source = pkgs.martin.doc-lock-extension;

      xdg.configFile."hk/config.pkl".text = ''
        amends "package://github.com/jdx/hk/releases/download/v${hk.version}/hk@${hk.version}#/Config.pkl"

        hooks {
          ["pre-commit"] {
            steps {
              ["doc-lock"] {
                check = "${docLockExe} staged"
              }
            }
          }
        }
      '';
    })
  ];
}
