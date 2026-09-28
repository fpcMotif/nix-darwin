{ lib, ... }:

{
  options.martin.development.docLock = lib.mkOption {
    type = lib.types.bool;
    default = true;
    example = false;
    description = ''
      Keep coding agents from changing comments and Markdown until the user
      asks for docs work in the session (pkgs/doc-lock.nix).

      On, it wires three things: the Claude Code hooks that run doc-lock, the
      user-level hk pre-commit step, and the "Docs lock" section of every
      agent guide. Set it false to roll all three back on the next switch.
      To switch the lock off without a rebuild, start the agent with
      DOC_LOCK_OFF=1 in its environment.
    '';
  };
}
