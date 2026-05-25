{ inputs, pkgs, lib, config, ... }:

# Claude runtime maintenance that intentionally mutates user-owned state.
# The main claude.nix module declares immutable files and the agent-skills
# bundle; this module keeps the post-writeBoundary fixups together.
let
  inherit (import ./claude-common.nix) skillTargetDirs disabledMattpocockSkills;

  dotClaude = inputs.dotfiles + "/dot_claude";
  homeDir = config.home.homeDirectory;

  renderChezmoi = src: pkgs.writeText (baseNameOf (toString src)) (
    builtins.replaceStrings
      [ "{{ .chezmoi.homeDir }}" ]
      [ homeDir ]
      (builtins.readFile src)
  );
in
{
  # Idempotently rewrites the 3 installed plugin Stop hook configs to
  # dispatch through stop-hook-debug.sh, which logs stdin/stdout/stderr/
  # exit-code to ~/.claude/debug-logs/stop-hooks.log. Original commands
  # are preserved in a sibling `.orig` file the first time we touch them
  # so they can be restored (`mv hooks.json.orig hooks.json`) when
  # diagnosis is done and this block is removed.
  #
  # Re-runs on every `darwin-rebuild switch`. Plugin updates that
  # refresh the cached hooks.json will revert the wrapping; next switch
  # re-applies it.
  home.activation.claudeStopHookDebug = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    wrap_stop_hook() {
      local hook_id="$1" file="$2"
      [ -f "$file" ] || { echo "stop-hook-debug: missing $file, skipping" >&2; return 0; }

      # Already wrapped? `any` over all entries (not just [0]) avoids
      # re-wrap stacking if a plugin update reorders Stop hook entries.
      if ${pkgs.jq}/bin/jq -e --arg w "stop-hook-debug.sh" \
          '[.hooks.Stop[]?.hooks[]?.command | contains($w)] | any' "$file" >/dev/null 2>&1; then
        return 0
      fi

      [ -f "$file.orig" ] || cp "$file" "$file.orig"

      local tmp
      tmp=$(mktemp)
      ${pkgs.jq}/bin/jq \
        --arg wrapper "${homeDir}/.claude/hooks/stop-hook-debug.sh" \
        --arg hookid "$hook_id" \
        '.hooks.Stop |= map(.hooks |= map(.command = ($wrapper + " " + $hookid + " " + .command)))' \
        "$file" > "$tmp" && mv "$tmp" "$file"
      echo "stop-hook-debug: wrapped $hook_id ($file)" >&2
    }

    base="${homeDir}/.claude/plugins/cache"
    wrap_stop_hook superpowers "$base/frad-dotclaude/superpowers/2.1.0/.claude-plugin/plugin.json"
    wrap_stop_hook ralph-loop  "$base/claude-plugins-official/ralph-loop/1.0.0/hooks/hooks.json"
    wrap_stop_hook codex       "$base/openai-codex/codex/1.0.4/hooks/hooks.json"
  '';

  # Claude can cache Anthropic-provided skills outside the Nix-managed skill
  # targets. Keep the disabled skills (currently grill-me — grill-with-docs is
  # preserved as the preferred planning skill) out of every picker source plus
  # active Claude Desktop sessions and the skills-plugin cache.
  home.activation.claudeDisableGrillSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for dir in ${lib.concatMapStringsSep " " (d: ''"${homeDir}/${d}"'') (lib.attrValues skillTargetDirs)}; do
      for skill in ${lib.escapeShellArgs disabledMattpocockSkills}; do
        rm -rf -- "$dir/$skill"
      done
    done

    sessions="${homeDir}/Library/Application Support/Claude/local-agent-mode-sessions"
    if [ -d "$sessions" ]; then
      # grep -lZ pre-filter: skip jq+mv on the 99% of session files
      # that don't mention the skill. Cuts a per-switch O(sessions)
      # spawn storm down to O(matches).
      while IFS= read -r -d "" file; do
        tmp=$(mktemp)
        ${pkgs.jq}/bin/jq '
          if (.slashCommands? | type) == "array" then
            .slashCommands = (.slashCommands - ["anthropic-skills:grill-me"])
          else
            .
          end
        ' "$file" > "$tmp" && mv "$tmp" "$file"
      done < <(${pkgs.findutils}/bin/find "$sessions" -type f -name "local_*.json" \
                 -exec ${pkgs.gnugrep}/bin/grep -lZ "anthropic-skills:grill-me" {} +)

      while IFS= read -r -d "" dir; do
        parent="$(${pkgs.coreutils}/bin/dirname "$dir")"
        disabled="$parent/../skills-disabled"
        mkdir -p "$disabled"
        rm -rf -- "$disabled/grill-me"
        mv "$dir" "$disabled/grill-me"
      done < <(${pkgs.findutils}/bin/find "$sessions/skills-plugin" -type d -path "*/skills/grill-me" -print0 2>/dev/null || true)
    fi
  '';

  # obra/superpowers (Nix-managed) is the canonical `brainstorming` source. The
  # frad-dotclaude/superpowers *plugin* ships its own `brainstorming`, so both
  # would otherwise surface in the picker. Park ONLY the plugin's `brainstorming`
  # into a sibling skills-disabled/ dir so exactly one survives (the obra one);
  # every other plugin skill (writing-plans, executing-plans, systematic-debugging,
  # behavior-driven-development, need-vet, agent-team-driven-development, ...) is
  # left live on purpose. Non-destructive and version-agnostic (globs the version
  # dir); re-runs each switch, so a plugin update that restores brainstorming/ is
  # re-parked on the next rebuild. The plugin's hooks/commands framework is
  # untouched (separate concern — see claudeStopHookDebug).
  home.activation.claudeDisableSuperpowersPluginBrainstorming = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for skills_dir in "${homeDir}"/.claude/plugins/cache/frad-dotclaude/superpowers/*/skills; do
      [ -d "$skills_dir/brainstorming" ] || continue
      disabled="$(${pkgs.coreutils}/bin/dirname "$skills_dir")/skills-disabled"
      mkdir -p "$disabled"
      rm -rf -- "$disabled/brainstorming"
      mv -- "$skills_dir/brainstorming" "$disabled/brainstorming"
    done
  '';

  # Claude rewrites theme, env vars, and plugin state into this file at
  # runtime, so a hard symlink would fight the app. Seed once on first
  # rebuild, then leave alone — same pattern as opencode.nix.
  home.activation.claudeSettingsSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    target="${homeDir}/.claude/settings.json"
    if [ ! -e "$target" ]; then
      run install -m 0644 ${renderChezmoi (dotClaude + "/settings.json.tmpl")} "$target"
    fi
  '';
}
