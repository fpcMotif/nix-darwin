{ config, lib, ... }:

{
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [ "--cmd" "z" ];
  };

  # `z` in non-interactive shells too: Claude Code's Bash tool runs
  # `zsh -l -c`, which never reaches .zshrc where zoxide init lives.
  # Interactive shells keep zoxide's own `z` (a function .zshrc defines later).
  programs.zsh.envExtra = lib.mkIf config.programs.zoxide.enable ''
    z() {
      if [ $# -eq 0 ]; then cd ~; return; fi
      if [ "$1" = - ]; then cd -; return; fi
      local d; d=$(zoxide query -- "$@") && cd -- "$d"
    }
  '';
}
