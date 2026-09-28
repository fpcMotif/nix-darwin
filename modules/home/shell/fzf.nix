{ lib, pkgs, ... }:

{
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    fileWidget = {
      command = "fd --type f --hidden --exclude .git --color=always";
      options = [
        "--preview 'bat --style=numbers --color=always --line-range :500 {}'"
      ];
    };
    changeDirWidget = {
      command = "fd --type d --hidden --exclude .git --color=always";
      options = [
        "--preview 'eza --tree --level=2 --icons --color=always --no-quotes {}'"
      ];
    };
    defaultOptions = [
      "--height=50%"
      "--layout=reverse"
      "--border"
      "--ansi"
      "--prompt='fzf> '"
      "--pointer='>'"
      "--marker='+'"
      "--color=fg:-1,bg:-1,hl:cyan,fg+:white,bg+:black,hl+:cyan"
      "--color=info:yellow,prompt:cyan,pointer:green,marker:yellow,spinner:green,header:cyan"
    ];
  };

  # When fzf is enabled, enhance zsh completion with fzf-tab
  programs.zsh.initContent = lib.mkAfter ''
    if (( $+functions[compdef] )) && [[ -r "${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh" ]]; then
      source "${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh"
      zstyle ':completion:*:git-checkout:*' sort false
      zstyle ':completion:*:descriptions' format '[%d]'
      zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath 2>/dev/null'
      zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza -1 --color=always $realpath 2>/dev/null'
      zstyle ':fzf-tab:*' switch-group '<' '>'
    fi
  '';
}
