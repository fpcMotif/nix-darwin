{ config, lib, pkgs, ... }:

let
  cfg = config.programs.worktrunk;

  # `wt config shell init zsh` prints a static script. Rendering it at build
  # time skips a wt fork on every shell start and pins the wrapper to this wt.
  zshInit = pkgs.runCommand "worktrunk-init.zsh" { } ''
    ${lib.getExe cfg.package} config shell init zsh > $out
  '';
in
{
  programs.worktrunk = {
    enable = true;
    enableZshIntegration = false;

    # Home Manager links config.toml read-only. Command approvals live in the
    # separate, mutable ~/.config/worktrunk/approvals.toml, so hook trust still
    # works. Every key wt would write back on a first-run prompt is set here.
    settings = {
      # Shell integration comes from this module, not `wt config shell install`.
      skip-shell-integration-prompt = true;

      # Upstream's default, pinned: sibling directories keep worktrees out of
      # the main checkout's search indexes and file watchers.
      worktree-path = "{{ repo_path }}/../{{ repo }}.{{ branch | sanitize }}";

      # Upstream's Claude recipe. --safe-mode skips hooks, MCP servers, and
      # skills, so a commit message does not start a full agent session.
      commit.generation.command =
        "MAX_THINKING_TOKENS=0 claude -p --no-session-persistence --model=haiku --tools='' --safe-mode --setting-sources='user' --system-prompt=''";

      # Unset prints a deprecation warning on every `wt list --format json`.
      list.json-schema = 2;
    };
  };

  # Default order 1000 runs after compinit (570), so the wrapper's compdef
  # registration takes effect.
  programs.zsh.initContent = ''
    source ${zshInit}
  '';
}
