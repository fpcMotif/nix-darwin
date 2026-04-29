setopt AUTO_CD
setopt INTERACTIVE_COMMENTS
setopt HIST_FCNTL_LOCK
setopt HIST_IGNORE_ALL_DUPS
setopt SHARE_HISTORY
unsetopt AUTO_REMOVE_SLASH
unsetopt HIST_EXPIRE_DUPS_FIRST
unsetopt EXTENDED_HISTORY

# PATH
export PATH=$HOME/.local/bin:$PATH
export PATH=$PNPM_HOME:$PATH
export PATH=$HOME/go/bin:$PATH
export PATH=$HOME/.cargo/bin:$PATH

# Autoload
autoload -U compinit; compinit
zmodload zsh/complist
autoload -Uz edit-command-line; zle -N edit-command-line
autoload -Uz add-zsh-hook

# Plugins supplied through Home Manager xdg.dataFile.
if [ -r "$ZSHAREDIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
  source "$ZSHAREDIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
if [ -r "$ZSHAREDIR/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
  source "$ZSHAREDIR/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi
if [ -r "$ZSHAREDIR/zsh-history-substring-search/zsh-history-substring-search.zsh" ]; then
  source "$ZSHAREDIR/zsh-history-substring-search/zsh-history-substring-search.zsh"
fi
fpath=($ZSHAREDIR/zsh-completions $fpath)

[[ $- == *i* ]] && source $ZSHAREDIR/fzf/completion.zsh 2> /dev/null
source $ZSHAREDIR/fzf/key-bindings.zsh 2> /dev/null

# Auto completion
zstyle ":completion:*:*:*:*:*" menu select
zstyle ":completion:*" use-cache yes
zstyle ":completion:*" special-dirs true
zstyle ":completion:*" squeeze-slashes true
zstyle ":completion:*" file-sort change
zstyle ":completion:*" matcher-list "m:{[:lower:][:upper:]}={[:upper:][:lower:]}" "r:|=*" "l:|=* r:|=*"
source $ZDOTDIR/keymap.zsh

# Tabtab for node cli programs, e.g. `pnpm`
source $ZDOTDIR/tabtab/pnpm.zsh

# Initialize tools
source $ZDOTDIR/function.zsh
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
