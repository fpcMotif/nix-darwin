{ lib, pkgs, ... }:

let
  copyPipe = ''sh -c 'b64=$(dd bs=1 count=100000 status=none | base64 | tr -d "\n"); printf "\033]52;c;%s\a" "$b64" > "$1"' sh #{client_tty}'';
in
{
  home.activation.checkNixManagedTmux = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    if [ -e "$HOME/.config/tmux/tmux.conf" ] && ! [ -L "$HOME/.config/tmux/tmux.conf" ]; then
      echo "ERROR: ~/.config/tmux/tmux.conf is still unmanaged." >&2
      echo "Please archive/remove it so Home Manager can manage tmux settings." >&2
      exit 1
    fi
  '';

  programs.tmux = {
    enable = true;
    keyMode = "vi";
    prefix = "C-;";
    escapeTime = 0;
    historyLimit = 50000;
    baseIndex = 1;
    mouse = true;
    focusEvents = true;
    aggressiveResize = true;
    terminal = "tmux-256color";
    shell = "${pkgs.zsh}/bin/zsh";
    plugins = [ ];

    extraConfig = ''
      set -g default-command "${pkgs.zsh}/bin/zsh -l"
      set -g display-time 4000
      set -g status-interval 5
      set -g status-keys emacs
      set -g pane-base-index 1
      set-window-option -g pane-base-index 1
      set-option -g renumber-windows on

      # Enable CSI-u key sequences and modern terminal features.
      set -s extended-keys always
      set -s extended-keys-format csi-u
      set -s terminal-features 'xterm*:clipboard:ccolour:cstyle:focus:title:extkeys'
      set -as terminal-features 'screen*:title'
      set -as terminal-features 'rxvt*:ignorefkeys'

      # Prefix and current-directory pane/window creation.
      unbind C-b
      set-option -g prefix C-\;
      bind \; send-prefix
      unbind %
      unbind '"'
      bind \\ split-window -h -c "#{pane_current_path}"
      bind Enter split-window -v -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"

      # Pane management.
      bind -r - resize-pane -D 2
      bind -r = resize-pane -U 2
      bind -r ] resize-pane -R 2
      bind -r [ resize-pane -L 2
      bind -r DC select-layout tiled
      bind x kill-pane
      unbind m
      unbind z
      bind m resize-pane -Z
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded"

      # Vi copy mode with OSC52 clipboard support; plugin bootstrap stays disabled.
      set-window-option -g mode-keys vi
      set -s set-clipboard external
      set -g allow-passthrough on
      bind v copy-mode
      bind -T copy-mode-vi q send-keys -X cancel
      bind -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi V send-keys -X select-line
      bind -T copy-mode-vi Escape send-keys -X clear-selection
      bind -T copy-mode-vi 'C-v' send-keys -X rectangle-toggle
      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "${copyPipe}"
      bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "${copyPipe}"

      set -g status-position top

      # Pane navigation while in copy mode.
      bind -T copy-mode-vi 'C-h' select-pane -L
      bind -T copy-mode-vi 'C-j' select-pane -D
      bind -T copy-mode-vi 'C-k' select-pane -U
      bind -T copy-mode-vi 'C-l' select-pane -R
      bind -T copy-mode-vi 'C-\\' select-pane -l
      bind -T copy-mode-vi 'C-Space' select-pane -t:.+
    '';
  };
}
