{ lib, ... }:

{
  home.activation.cleanupLegacyDotfiles = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    remove_legacy_path() {
      if [ -e "$1" ] || [ -L "$1" ]; then
        rm -rf -- "$1"
      fi
    }

    remove_legacy_path "$HOME/.zshrc"
    remove_legacy_path "$HOME/.zshenv"
    remove_legacy_path "$HOME/.zprofile"
    remove_legacy_path "$HOME/.gitconfig"

    remove_legacy_path "$HOME/.config/zsh/.zshrc"
    remove_legacy_path "$HOME/.config/zsh/.zshenv"
    remove_legacy_path "$HOME/.config/zsh/rc.d"
    remove_legacy_path "$HOME/.config/sheldon/plugins.toml"

    remove_legacy_path "$HOME/.config/starship.toml"
    remove_legacy_path "$HOME/.config/ghostty/config"
    remove_legacy_path "$HOME/.config/kitty/kitty.conf"
    remove_legacy_path "$HOME/.config/kitty/diff.conf"
    remove_legacy_path "$HOME/.config/git/config"
    remove_legacy_path "$HOME/.config/git/ignore"
    remove_legacy_path "$HOME/.config/jj/config.toml"

    remove_legacy_path "$HOME/.local/bin/claude"
    remove_legacy_path "$HOME/.local/bin/droid"
    remove_legacy_path "$HOME/.local/bin/opencode"
    remove_legacy_path "$HOME/.local/bin/opencode-electron"
    remove_legacy_path "$HOME/.local/bin/npm"
    remove_legacy_path "$HOME/.local/bin/npx"
    remove_legacy_path "$HOME/.local/bin/pnpm"

    remove_legacy_path "$HOME/.config/ghostty/themes/rose-pine-moon"
    remove_legacy_path "$HOME/.config/ghostty/unmanaged-backups"
    remove_legacy_path "$HOME/.config/zsh/.zcompdump"
    remove_legacy_path "$HOME/.config/chezmoi"
    remove_legacy_path "$HOME/.zshrc.pre-chezmoi.bak"
    remove_legacy_path "$HOME/.config/crush/crush.json.bak"
    for f in "$HOME"/.config/zsh/.zcompdump.* "$HOME"/.config/crush/crush.json.bak.*; do
      [ -e "$f" ] && rm -f -- "$f"
    done
  '';
}
