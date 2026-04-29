# Widgets
function vi-yank-wrapped {
  local last_key="$KEYS[-1]"
  local ori_buffer="$CUTBUFFER"

  zle vi-yank
  if [[ "$last_key" = "Y" ]] then
    echo -n "$CUTBUFFER" | pbcopy -i
    CUTBUFFER="$ori_buffer"
  fi
}
zle -N vi-yank-wrapped

bindkey -v
bindkey -s "^y" "y\n"

# Menu
bindkey -M menuselect "^I" complete-word
bindkey -M menuselect "^[" send-break
bindkey -M menuselect "^P" up-line-or-history
bindkey -M menuselect "^N" down-line-or-history
bindkey -M menuselect "^B" backward-char
bindkey -M menuselect "^F" forward-char

# Normal mode additions, keeping conventional vi h/j/k/l movement.
bindkey -M vicmd "^W" backward-delete-word
bindkey -M vicmd "^L" clear-screen
bindkey -M vicmd "^M" accept-line
bindkey -M vicmd "," edit-command-line
bindkey -M vicmd "Y" vi-yank-wrapped
bindkey -M vicmd "y" vi-yank-wrapped

# Insert mode additions.
bindkey -M viins "^?" backward-delete-char
bindkey -M viins "^W" backward-delete-word
bindkey -M viins "^P" history-substring-search-up
bindkey -M viins "^N" history-substring-search-down
bindkey -M viins "^[[44;5u" edit-command-line

# Visual mode additions.
bindkey -M visual "^[" deactivate-region
bindkey -M visual "aw" select-a-word
bindkey -M visual "aW" select-a-blank-word
bindkey -M visual "aa" select-a-shell-word
bindkey -M visual "iw" select-in-word
bindkey -M visual "iW" select-in-blank-word
bindkey -M visual "is" select-in-shell-word
bindkey -M visual "x" vi-delete
bindkey -M visual "p" put-replace-selection

# Operator pending text objects.
bindkey -M viopp "^[" vi-cmd-mode
bindkey -M viopp "aw" select-a-word
bindkey -M viopp "aW" select-a-blank-word
bindkey -M viopp "aa" select-a-shell-word
bindkey -M viopp "iw" select-in-word
bindkey -M viopp "iW" select-in-blank-word
bindkey -M viopp "is" select-in-shell-word
