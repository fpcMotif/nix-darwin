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

    # Pre-Nix imperative drift in ~/.claude/ (chezmoi-rendered or hand-placed).
    # Nix now owns these as read-only symlinks; remove the stale flat files
    # so home.file activation can claim the paths without conflict.
    # NOTE: settings.json is intentionally NOT cleared — Claude mutates it
    # at runtime; the seed activation in claude.nix only writes if absent.
    remove_legacy_path "$HOME/.claude/CLAUDE.md"
    remove_legacy_path "$HOME/.claude/claude.md"
    remove_legacy_path "$HOME/.claude/statusline-command.sh"

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

    # === Nix-owned agent-skill picker dirs ===
    # `programs.agent-skills` (modules/home/claude.nix) exposes every skill
    # under these picker dirs as ONE `home.file` symlink — even skills built
    # as a real directory in the store (packages-injected skills like
    # `review`) get a single symlink at the
    # picker path pointing at that store directory. Something outside Nix
    # (a `skill-router load`/`sync` run, a manual skill install, ...) has
    # left real, writable copies behind at some of those same paths instead
    # of a symlink — e.g. $HOME/.agents/skills/research as a plain directory
    # with its own stray agents/openai.yaml sidecar. Home Manager's own
    # checkLinkTargets/linkGeneration refuse to clobber a real directory, so
    # activation dies outright the next time Nix tries to place its symlink
    # there:
    #   cmp: .../home-manager-files/.agents/skills/research: Is a directory
    #   ln: /Users/.../.agents/skills/research: cannot overwrite directory
    # This is exactly the ralph-loop failure mode from before (removed from
    # the curated sources, but its stale materialized copy still blocked
    # activation until it was deleted by hand) — fix it generally instead of
    # one skill id at a time.
    #
    # Purge only entries the *new* generation is actually about to place: for
    # every id present at this same relative path in $newGenPath/home-files,
    # if the live path exists and is NOT a symlink, remove it so Nix can
    # claim it. $newGenPath is set by the outer activation script before any
    # home.activation fragment runs. Anything NOT part of the current bundle
    # (leftover ids no longer selected, or skills some other tool manages
    # directly under these dirs) has no counterpart in home-files and is left
    # untouched.
    purge_stale_skill_dirs() {
      local newGenFiles
      newGenFiles="$(readlink -e "$newGenPath/home-files" 2>/dev/null || true)"
      [ -n "$newGenFiles" ] || return 0

      local skills_rel
      # Keep in sync with `skillTargetDirs` in modules/home/claude.nix.
      for skills_rel in \
        .agents/skills \
        .claude/skills \
        .cursor/skills \
        .codex/skills \
        .config/agents/skills \
        .config/crush/skills \
        .factory/skills \
        .config/opencode/skills \
        .pi/agent/skills
      do
        local src="$newGenFiles/$skills_rel" dst="$HOME/$skills_rel"
        [ -d "$src" ] && [ -d "$dst" ] || continue

        local entry name live
        for entry in "$src"/*; do
          [ -e "$entry" ] || continue
          name="$(basename -- "$entry")"
          live="$dst/$name"
          if [ -e "$live" ] && [ ! -L "$live" ]; then
            rm -rf -- "$live"
          fi
        done
      done
    }
    purge_stale_skill_dirs
  '';
}
