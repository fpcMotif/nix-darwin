{ lib, pkgs, ... }:

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

    # Remove hand-placed files that Nix now links, so activation can claim
    # them. settings.json stays: Claude mutates it at runtime.
    remove_legacy_path "$HOME/.claude/CLAUDE.md"

    # Drop the codedb-pro blocker hooks, and plain copies of hooks Nix now
    # links; a symlink there is already ours.
    for h in block-legacy-tools block-native-tools codedb-block-legacy codedbpro-gate \
             auto-verify-edit auto-log-error pre-compact-save post-compact-reload codedb-warmup; do
      f="$HOME/.claude/hooks/$h.sh"
      if [ -e "$f" ] && [ ! -L "$f" ]; then remove_legacy_path "$f"; fi
    done
    # codedbpro was registered only in ~/.mcp.json; nothing in the repo owns it.
    if [ -f "$HOME/.mcp.json" ] && ${pkgs.jq}/bin/jq -e ".mcpServers.codedbpro" "$HOME/.mcp.json" >/dev/null 2>&1; then
      tmp=$(mktemp)
      ${pkgs.jq}/bin/jq "del(.mcpServers.codedbpro)" "$HOME/.mcp.json" > "$tmp" && mv -- "$tmp" "$HOME/.mcp.json"
    fi
    # aily-md is a per-project skill (Feishu aily docs); it leaves the global pickers.
    for d in .claude/skills .agents/skills .config/crush/skills .config/opencode/skills .pi/agent/skills .codex/skills .cursor/skills .factory/skills; do
      if [ -L "$HOME/$d/aily-md" ]; then remove_legacy_path "$HOME/$d/aily-md"; fi
    done
    # hyperframes and related video skills are per-project; prune them from global pickers.
    for d in .claude/skills .agents/skills .config/crush/skills .config/opencode/skills .pi/agent/skills .codex/skills .cursor/skills .factory/skills .config/agents/skills .gemini/skills .gemini/config/skills; do
      for skill in hyperframes hyperframes-cli faceless-explainer hyperframes-animation hyperframes-registry hyperframes-creative general-video hyperframes-core hyperframes-audio hyperframes-studio media-use hyperframes-keyframes; do
        if [ -L "$HOME/$d/$skill" ] || [ -d "$HOME/$d/$skill" ]; then remove_legacy_path "$HOME/$d/$skill"; fi
      done
    done
    remove_legacy_path "$HOME/.claude/claude.md"
    remove_legacy_path "$HOME/.claude/statusline-command.sh"
    # Code search routing files were hand-installed on 2026-09-08 before Nix
    # owned them (claude.nix home.file). Same idiom: clear the flat copies so
    # activation can place the store symlinks.
    remove_legacy_path "$HOME/.claude/search-eval.md"
    remove_legacy_path "$HOME/.claude/hooks/search-guard.sh"
    remove_legacy_path "$HOME/.claude/hooks/read-guard.sh"
    remove_legacy_path "$HOME/.claude/hooks/search-warmup.sh"
    remove_legacy_path "$HOME/.local/bin/tg"
    remove_legacy_path "$HOME/.config/ripgrep/agent-config"
    # tgrep was retired 2026-09-14: a hand-installed binary plus a 43 GB index cache.
    remove_legacy_path "$HOME/.local/bin/tgrep"
    remove_legacy_path "$HOME/.cache/tgrep"

    remove_legacy_path "$HOME/.local/bin/opencode"
    remove_legacy_path "$HOME/.local/bin/opencode-electron"
    remove_legacy_path "$HOME/.local/bin/npm"
    remove_legacy_path "$HOME/.local/bin/npx"
    remove_legacy_path "$HOME/.local/bin/pnpm"

    remove_legacy_path "$HOME/.config/ghostty/themes/rose-pine-moon"
    remove_legacy_path "$HOME/.config/ghostty/unmanaged-backups"
    remove_legacy_path "$HOME/.config/zsh/.zcompdump"
    remove_legacy_path "$HOME/.config/crush/crush.json.bak"
    for f in "$HOME"/.config/zsh/.zcompdump.* "$HOME"/.config/crush/crush.json.bak.*; do
      [ -e "$f" ] && rm -f -- "$f"
    done
    for f in "$HOME"/result "$HOME"/result-*; do
      [ -L "$f" ] && rm -f -- "$f"
    done
    [ -L "$HOME/.gemini/config/skills" ] && rm -f -- "$HOME/.gemini/config/skills"

    # === Nix-owned agent-skill picker dirs ===
    # Home Manager won't replace a real dir with its symlink. Remove a live
    # non-symlink only where the new generation places a skill; leave the rest.
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
