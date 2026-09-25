{
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
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
}
