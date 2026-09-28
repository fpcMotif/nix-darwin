{ config, lib, pkgs, ... }:

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

  config = lib.mkIf config.martin.development.docLock {
    home.file.".pi/agent/extensions/doc-lock.ts".source = pkgs.martin.doc-lock-extension;
    home.file.".omp/agent/hooks/pre/doc-lock.ts".source = pkgs.martin.doc-lock-extension;
  };
}
