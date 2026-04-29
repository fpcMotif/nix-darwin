# Zsh root
ZDOTDIR=$HOME/.config/zsh
ZSHAREDIR=$HOME/.local/share/zsh

# Zsh history and mode timing
HISTFILE=$ZDOTDIR/.history
HISTSIZE=10000
SAVEHIST=10000
KEYTIMEOUT=1
HISTORY_SUBSTRING_SEARCH_PREFIXED=1

# Temporary variables for search defaults
__TREE_IGNORE="-I '.git' -I '*.py[co]' -I '__pycache__' $__TREE_IGNORE"
__FD_COMMAND="-L -H --no-ignore-vcs ${__TREE_IGNORE//-I/-E} $__FD_COMMAND"

# Software-specific defaults
export EDITOR="nvim"
export VISUAL="nvim"
export BAT_THEME="Catppuccin Mocha"
export PNPM_HOME=$HOME/Library/pnpm

export LESSKEYIN=$HOME/.config/less/.lesskey
export LESSHISTFILE=$HOME/.config/less/.lesshst

export FZF_DEFAULT_COMMAND="fd $__FD_COMMAND"
if [ -r "$ZDOTDIR/fzf.zsh" ]; then
  source "$ZDOTDIR/fzf.zsh"
fi

# Clean up
unset __TREE_IGNORE
unset __FD_COMMAND
