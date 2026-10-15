#!/usr/bin/env bash
# The Nix sandbox cannot see the live picker dirs, ~/.claude settings, or plugin cache, so
# tests/unit/skill-hygiene-test.nix cannot prove what activation applied
# (docs/adr/0004-macos-settings-testing-strategy.md).
set -uo pipefail

pass=0
fail=0
skip=0

green() { printf '\033[32m%s\033[0m' "$1"; }
red() { printf '\033[31m%s\033[0m' "$1"; }
yellow() { printf '\033[33m%s\033[0m' "$1"; }

ok() {
  printf '  %s %s\n' "$(green PASS)" "$1"
  pass=$((pass + 1))
}
bad() {
  printf '  %s %s\n' "$(red FAIL)" "$1"
  fail=$((fail + 1))
}
na() {
  printf '  %s %s\n' "$(yellow SKIP)" "$1"
  skip=$((skip + 1))
}

section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

require_tool_or_exit() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'verify-agent-skills: missing required tool: %s\n' "$1" >&2
    exit 2
  }
}
require_tool_or_exit jq

# The live manifest only exists after a switch. AGENT_SKILLS_MANIFEST lets a
# `nix build ...home.file."<path>".source` output be checked before one.
MANIFEST="${AGENT_SKILLS_MANIFEST:-${HOME}/.config/agent-skills/manifest.json}"
CLAUDE_SKILLS="${HOME}/.claude/skills"
AGENTS_SKILLS="${HOME}/.agents/skills"
SETTINGS="${HOME}/.claude/settings.json"
LOCAL_SETTINGS="${HOME}/.claude/settings.local.json"

if [ ! -f "$MANIFEST" ]; then
  printf 'verify-agent-skills: missing %s -- run `just switch` first\n' "$MANIFEST" >&2
  exit 2
fi

manifest_query() { jq -r "$1" "$MANIFEST"; }

# The cache keys each install as <marketplace>/<plugin>, the reverse of the <plugin>@<marketplace> id.
PLUGIN_ID=$(manifest_query '.pluginId')
PLUGIN_CACHE="${HOME}/.claude/plugins/cache/${PLUGIN_ID#*@}/${PLUGIN_ID%@*}"

# Not `mapfile`: it is a bash-4 builtin and macOS /bin/bash is 3.2, so the
# system bash would produce empty lists and pass everything.
CLAUDE_HIDDEN=(); PLUGIN_PROVIDED=(); EXCLUDED=()
LOCAL_SKILLS=(); DENIED=(); TARGET_DIRS=()
while IFS= read -r item; do [ -n "$item" ] && CLAUDE_HIDDEN+=("$item"); done < <(manifest_query '.claudeHidden[]')
while IFS= read -r item; do [ -n "$item" ] && PLUGIN_PROVIDED+=("$item"); done < <(manifest_query '.pluginProvided[]')
while IFS= read -r item; do [ -n "$item" ] && EXCLUDED+=("$item"); done < <(manifest_query '.excluded[]')
while IFS= read -r item; do [ -n "$item" ] && LOCAL_SKILLS+=("$item"); done < <(manifest_query '.localSkills[]')
while IFS= read -r item; do [ -n "$item" ] && DENIED+=("$item"); done < <(manifest_query '.deniedPluginSkills[]')
while IFS= read -r item; do [ -n "$item" ] && TARGET_DIRS+=("$item"); done < <(manifest_query '.targetDirs[]')

# Claude Code reads settings.local.json over settings.json. The /skills TUI
# writes to the local file, so a UI toggle can silently override the managed
# value.
effective_override() {
  local id="$1" override=""
  if [ -f "$LOCAL_SETTINGS" ]; then
    override=$(jq -r --arg k "$id" '.skillOverrides[$k] // empty' "$LOCAL_SETTINGS" 2>/dev/null)
  fi
  if [ -z "$override" ] && [ -f "$SETTINGS" ]; then
    override=$(jq -r --arg k "$id" '.skillOverrides[$k] // empty' "$SETTINGS" 2>/dev/null)
  fi
  printf '%s' "${override:-on}"
}

section "1. Claude-visible duplicates (bundle copy must be hidden)"
# Bash before 4.4 treats an empty array as unset under `set -u`, hence the
# `${a[@]+...}` guard on every array expansion.
for id in ${CLAUDE_HIDDEN[@]+"${CLAUDE_HIDDEN[@]}"}; do
  got=$(effective_override "$id")
  if [ "$got" = "off" ]; then
    ok "$id hidden from Claude (skillOverrides=off)"
  else
    bad "$id has skillOverrides='$got', expected 'off' -- it is listed twice (bundle + plugin)"
  fi
done

section "2. Hidden ids are actually replaced by the plugin"
# The failure mode of deriving the hidden set from the flake pin: if the pin
# runs AHEAD of the plugin, an id gets hidden with nothing to replace it.
if jq -e --arg id "$PLUGIN_ID" '.enabledPlugins[$id] == true' "$SETTINGS" >/dev/null 2>&1; then
  ok "$PLUGIN_ID enabled in $SETTINGS"
else
  bad "$PLUGIN_ID is not enabled in $SETTINGS -- every hidden id is now invisible to Claude"
fi
if [ -d "$PLUGIN_CACHE" ]; then
  declared=$(find "$PLUGIN_CACHE" -maxdepth 3 -name plugin.json -path '*/.claude-plugin/*' \
    -exec jq -r '.skills[]? | split("/") | last' {} + 2>/dev/null | sort -u)
  for id in ${PLUGIN_PROVIDED[@]+"${PLUGIN_PROVIDED[@]}"}; do
    if printf '%s\n' "$declared" | grep -qx "$id"; then
      ok "$id is declared by the enabled plugin"
    else
      bad "$id is hidden from Claude but the plugin does not declare it -- the flake pin is ahead of the plugin, so this skill is now invisible"
    fi
  done
  # Claude reads the plugin copy, every other agent the bundle copy. Different
  # cadences (plugin release vs flake pin) make drift expected, not a failure.
  drift=0
  for id in ${PLUGIN_PROVIDED[@]+"${PLUGIN_PROVIDED[@]}"}; do
    bundle="$CLAUDE_SKILLS/$id/SKILL.md"
    plugin=$(find "$PLUGIN_CACHE" -path "*/skills/*/$id/SKILL.md" -print -quit 2>/dev/null)
    if [ -f "$bundle" ] && [ -n "$plugin" ] && ! cmp -s "$bundle" "$plugin"; then
      drift=$((drift + 1))
    fi
  done
  if [ "$drift" -eq 0 ]; then
    ok "plugin and bundle SKILL.md identical for every hidden id"
  else
    na "$drift hidden ids differ between plugin and bundle text (plugin release vs flake pin); Claude reads the plugin, other agents the bundle"
  fi
else
  na "plugin cache not found at $PLUGIN_CACHE"
fi

section "3. Refused ids are gone from the plugin manifest"
# skillOverrides cannot touch a plugin skill, so these are pruned out of the
# cached manifest instead. A plugin update restores them until the next switch.
if [ -d "$PLUGIN_CACHE" ]; then
  for id in ${DENIED[@]+"${DENIED[@]}"}; do
    if find "$PLUGIN_CACHE" -maxdepth 3 -name plugin.json -path '*/.claude-plugin/*' \
      -exec jq -e --arg id "$id" \
      'any(.skills[]?; split("/") | last == $id)' {} + >/dev/null 2>&1; then
      bad "$id is still declared in a cached plugin manifest -- re-run \`just switch\` (a plugin update restores it)"
    else
      ok "$id pruned from the plugin manifest"
    fi
  done
else
  na "plugin cache not found at $PLUGIN_CACHE"
fi

section "4. Deny rules present (covers the post-update window)"
if [ -f "$SETTINGS" ]; then
  for id in ${DENIED[@]+"${DENIED[@]}"}; do
    if jq -e --arg r "Skill(mattpocock-skills:${id})" \
      'any(.permissions.deny[]?; . == $r)' "$SETTINGS" >/dev/null 2>&1; then
      ok "Skill(mattpocock-skills:$id) denied"
    else
      bad "missing deny rule Skill(mattpocock-skills:$id) in $SETTINGS"
    fi
  done
else
  na "$SETTINGS not found"
fi

section "5. Other agents keep the full bundle (the hard constraint)"
# Codex, Droid, OpenCode and Crush have no plugin system, so the bundle is their only copy.
if [ -d "$AGENTS_SKILLS" ]; then
  missing=0
  for id in ${PLUGIN_PROVIDED[@]+"${PLUGIN_PROVIDED[@]}"}; do
    if [ ! -e "$AGENTS_SKILLS/$id/SKILL.md" ]; then
      bad "$id hidden from Claude but ALSO absent from $AGENTS_SKILLS -- Codex/Droid lost it"
      missing=$((missing + 1))
    fi
  done
  [ "$missing" -eq 0 ] && ok "all ${#PLUGIN_PROVIDED[@]} plugin-duplicated skills still present in ~/.agents/skills"
else
  na "$AGENTS_SKILLS not found"
fi

section "6. Vendored skills survive on every surface"
for id in ${LOCAL_SKILLS[@]+"${LOCAL_SKILLS[@]}"}; do
  got=$(effective_override "$id")
  if [ "$got" != "on" ]; then
    bad "vendored skill $id has skillOverrides='$got' -- it has no plugin copy, so it is now unreachable in Claude"
  elif [ -e "$CLAUDE_SKILLS/$id/SKILL.md" ]; then
    ok "$id present and visible"
  else
    bad "vendored skill $id missing from $CLAUDE_SKILLS"
  fi
done

section "7. Excluded ids absent from every picker dir"
for dir in ${TARGET_DIRS[@]+"${TARGET_DIRS[@]}"}; do
  [ -d "${HOME}/${dir}" ] || continue
  for id in ${EXCLUDED[@]+"${EXCLUDED[@]}"}; do
    if [ -e "${HOME}/${dir}/${id}" ]; then
      bad "excluded skill '$id' reappeared in ~/${dir} (the external \`skills\` CLI re-installs some of these)"
    fi
  done
done
ok "excluded-id sweep completed over ${#TARGET_DIRS[@]} picker dirs"

section "8. No dangling skill symlinks"
for dir in ${TARGET_DIRS[@]+"${TARGET_DIRS[@]}"}; do
  [ -d "${HOME}/${dir}" ] || continue
  while IFS= read -r link; do
    [ -n "$link" ] || continue
    bad "dangling symlink ~/${dir}/$(basename "$link") -> $(readlink "$link")"
  done < <(find "${HOME}/${dir}" -maxdepth 1 -type l ! -exec test -e {} \; -print 2>/dev/null)
done
ok "dangling-symlink sweep completed"

section "9. Global CLAUDE.md hygiene (real tools only, dead tools removed)"
CLAUDE_MD="${HOME}/.claude/CLAUDE.md"
CLAUDE_DEV="${HOME}/.claude/guidance/development.md"
if [ -f "$CLAUDE_MD" ]; then
  claude_md_content=$(cat "$CLAUDE_MD" "$CLAUDE_DEV" 2>/dev/null || cat "$CLAUDE_MD")
  mentions() { printf '%s\n' "$claude_md_content" | grep -q "$@"; }

  banned_found=0
  for term in gemini deepwiki mgrep lazygit deep-research chezmoi; do
    if mentions -i "$term"; then
      bad "banned term '$term' found in $CLAUDE_MD"
      banned_found=1
    fi
  done
  [ "$banned_found" -eq 0 ] && ok "no dead/banned tools found in $CLAUDE_MD"

  tools_missing=0
  for tool in fd rg bat eza dust procs btm ax delta hyperfine fff; do
    if ! mentions "\b$tool\b"; then
      bad "required tool '$tool' not mentioned in $CLAUDE_MD"
      tools_missing=1
    fi
  done
  if ! mentions "ast-grep" && ! mentions "\bsg\b"; then
    bad "ast-grep/sg not mentioned in $CLAUDE_MD"
    tools_missing=1
  fi
  [ "$tools_missing" -eq 0 ] && ok "all required modern tools present in $CLAUDE_MD"
else
  na "$CLAUDE_MD does not exist"
fi

printf '\n%s: %d passed, %d failed, %d skipped\n' \
  "$(basename "$0")" "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
