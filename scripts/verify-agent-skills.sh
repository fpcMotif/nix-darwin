#!/usr/bin/env bash
# Tier 2 (opt-in, real-machine) verification of the agent-skill surfaces.
# Run this AFTER `just switch`. It answers the one question the hermetic Tier 1
# check (tests/unit/skill-hygiene-test.nix) structurally cannot: is every skill
# id advertised to Claude Code EXACTLY once, while every other agent still sees
# the full bundle?
#
# Division of labour (see docs/adr/0004-macos-settings-testing-strategy.md):
#   * Tier 1 (nix flake check) proves the configuration DECLARES the curation.
#   * Tier 2 (this script)      proves activation APPLIED it to the live picker
#                               dirs, the live settings.json, and the plugin cache.
#
# Deliberately NOT wired into `nix flake check`: it reads mutable machine state
# (~/.claude/settings*.json, the plugin cache, ~/.agents/skills) that the Nix
# sandbox cannot see. Invoke via `just verify-skills` or directly.
#
# Expectations come from ~/.config/agent-skills/manifest.json, which
# modules/home/claude.nix regenerates on every switch -- so this script never
# restates the curation lists and cannot drift from them.
#
# Exit status: 0 iff there are zero FAILs. SKIPs (a surface that does not exist
# on this host) do not fail the run.
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

need() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'verify-agent-skills: missing required tool: %s\n' "$1" >&2
    exit 2
  }
}
need jq

# Overridable so the check can be dry-run against a manifest built straight out
# of `nix build ...home.file."<path>".source` before a switch has applied one.
MANIFEST="${AGENT_SKILLS_MANIFEST:-${HOME}/.config/agent-skills/manifest.json}"
CLAUDE_SKILLS="${HOME}/.claude/skills"
AGENTS_SKILLS="${HOME}/.agents/skills"
SETTINGS="${HOME}/.claude/settings.json"
LOCAL_SETTINGS="${HOME}/.claude/settings.local.json"
PLUGIN_CACHE="${HOME}/.claude/plugins/cache/claude-plugins-official/mattpocock-skills"

if [ ! -f "$MANIFEST" ]; then
  printf 'verify-agent-skills: missing %s -- run `just switch` first\n' "$MANIFEST" >&2
  exit 2
fi

jqm() { jq -r "$1" "$MANIFEST"; }

# Read a manifest array into a named global. Deliberately not `mapfile`: that is
# a bash-4 builtin and /bin/bash on macOS is still 3.2, so a script invoked with
# the system bash would silently produce empty lists and "pass" everything.
CLAUDE_HIDDEN=(); PLUGIN_PROVIDED=(); EXCLUDED=()
LOCAL_SKILLS=(); DENIED=(); TARGET_DIRS=()
while IFS= read -r x; do [ -n "$x" ] && CLAUDE_HIDDEN+=("$x"); done < <(jqm '.claudeHidden[]')
while IFS= read -r x; do [ -n "$x" ] && PLUGIN_PROVIDED+=("$x"); done < <(jqm '.pluginProvided[]')
while IFS= read -r x; do [ -n "$x" ] && EXCLUDED+=("$x"); done < <(jqm '.excluded[]')
while IFS= read -r x; do [ -n "$x" ] && LOCAL_SKILLS+=("$x"); done < <(jqm '.localSkills[]')
while IFS= read -r x; do [ -n "$x" ] && DENIED+=("$x"); done < <(jqm '.deniedPluginSkills[]')
while IFS= read -r x; do [ -n "$x" ] && TARGET_DIRS+=("$x"); done < <(jqm '.targetDirs[]')

# Empty arrays under `set -u` are an error before bash 4.4, so every expansion
# below uses the `${a[@]+...}` guard rather than a bare `${a[@]}`.

# The effective skillOverrides value for an id, honouring Claude Code's
# precedence (user settings.json < settings.local.json). The /skills TUI writes
# to the local file, so a UI toggle can silently override the managed value.
effective_override() { # id
  local id="$1" v=""
  if [ -f "$LOCAL_SETTINGS" ]; then
    v=$(jq -r --arg k "$id" '.skillOverrides[$k] // empty' "$LOCAL_SETTINGS" 2>/dev/null)
  fi
  if [ -z "$v" ] && [ -f "$SETTINGS" ]; then
    v=$(jq -r --arg k "$id" '.skillOverrides[$k] // empty' "$SETTINGS" 2>/dev/null)
  fi
  printf '%s' "${v:-on}"
}

# ---------------------------------------------------------------------------
section "1. Claude-visible duplicates (bundle copy must be hidden)"
# Every id the plugin also provides must be present on disk but overridden
# "off", so Claude Code lists it once -- as mattpocock-skills:<id>.
for id in ${CLAUDE_HIDDEN[@]+"${CLAUDE_HIDDEN[@]}"}; do
  [ -n "$id" ] || continue
  got=$(effective_override "$id")
  if [ "$got" = "off" ]; then
    ok "$id hidden from Claude (skillOverrides=off)"
  else
    bad "$id has skillOverrides='$got', expected 'off' -- it is listed twice (bundle + plugin)"
  fi
done

# ---------------------------------------------------------------------------
section "2. Hidden ids are actually replaced by the plugin"
# The failure mode of deriving the hidden set from the flake pin: if the pin
# runs AHEAD of the plugin, an id gets hidden with nothing to replace it.
if [ -d "$PLUGIN_CACHE" ]; then
  declared=$(find "$PLUGIN_CACHE" -maxdepth 3 -name plugin.json -path '*/.claude-plugin/*' \
    -exec jq -r '.skills[]? | split("/") | last' {} + 2>/dev/null | sort -u)
  for id in ${PLUGIN_PROVIDED[@]+"${PLUGIN_PROVIDED[@]}"}; do
    [ -n "$id" ] || continue
    if printf '%s\n' "$declared" | grep -qx "$id"; then
      ok "$id is declared by the enabled plugin"
    else
      bad "$id is hidden from Claude but the plugin does not declare it -- the flake pin is ahead of the plugin, so this skill is now invisible"
    fi
  done
else
  na "plugin cache not found at $PLUGIN_CACHE"
fi

# ---------------------------------------------------------------------------
section "3. Refused ids are gone from the plugin manifest"
# skillOverrides cannot touch a plugin skill, so these are pruned out of the
# cached manifest instead. A plugin update restores them until the next switch.
if [ -d "$PLUGIN_CACHE" ]; then
  for id in ${DENIED[@]+"${DENIED[@]}"}; do
    [ -n "$id" ] || continue
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

# ---------------------------------------------------------------------------
section "4. Deny rules present (covers the post-update window)"
if [ -f "$SETTINGS" ]; then
  for id in ${DENIED[@]+"${DENIED[@]}"}; do
    [ -n "$id" ] || continue
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

# ---------------------------------------------------------------------------
section "5. Other agents keep the full bundle (the hard constraint)"
# Codex/Droid/OpenCode/Crush have no plugin system. Everything hidden from
# Claude MUST still be readable from their own picker dirs.
if [ -d "$AGENTS_SKILLS" ]; then
  missing=0
  for id in ${PLUGIN_PROVIDED[@]+"${PLUGIN_PROVIDED[@]}"}; do
    [ -n "$id" ] || continue
    [ -e "$AGENTS_SKILLS/$id/SKILL.md" ] || {
      bad "$id hidden from Claude but ALSO absent from $AGENTS_SKILLS -- Codex/Droid lost it"
      missing=$((missing + 1))
    }
  done
  [ "$missing" -eq 0 ] && ok "all ${#PLUGIN_PROVIDED[@]} plugin-duplicated skills still present in ~/.agents/skills"
else
  na "$AGENTS_SKILLS not found"
fi

# ---------------------------------------------------------------------------
section "6. Vendored skills survive on every surface"
# These have no plugin copy to fall back on, so they must never be hidden.
for id in ${LOCAL_SKILLS[@]+"${LOCAL_SKILLS[@]}"}; do
  [ -n "$id" ] || continue
  got=$(effective_override "$id")
  if [ "$got" != "on" ]; then
    bad "vendored skill $id has skillOverrides='$got' -- it has no plugin copy, so it is now unreachable in Claude"
  elif [ -e "$CLAUDE_SKILLS/$id/SKILL.md" ]; then
    ok "$id present and visible"
  else
    bad "vendored skill $id missing from $CLAUDE_SKILLS"
  fi
done

# ---------------------------------------------------------------------------
section "7. Excluded ids absent from every picker dir"
for dir in ${TARGET_DIRS[@]+"${TARGET_DIRS[@]}"}; do
  [ -d "${HOME}/${dir}" ] || continue
  for id in ${EXCLUDED[@]+"${EXCLUDED[@]}"}; do
    [ -n "$id" ] || continue
    if [ -e "${HOME}/${dir}/${id}" ]; then
      bad "excluded skill '$id' reappeared in ~/${dir} (the external \`skills\` CLI re-installs some of these)"
    fi
  done
done
ok "excluded-id sweep completed over ${#TARGET_DIRS[@]} picker dirs"

# ---------------------------------------------------------------------------
section "8. No dangling skill symlinks"
for dir in ${TARGET_DIRS[@]+"${TARGET_DIRS[@]}"}; do
  [ -d "${HOME}/${dir}" ] || continue
  while IFS= read -r link; do
    [ -n "$link" ] || continue
    bad "dangling symlink ~/${dir}/$(basename "$link") -> $(readlink "$link")"
  done < <(find "${HOME}/${dir}" -maxdepth 1 -type l ! -exec test -e {} \; -print 2>/dev/null)
done
ok "dangling-symlink sweep completed"

# ---------------------------------------------------------------------------
section "9. Global CLAUDE.md hygiene (real tools only, dead tools removed)"
CLAUDE_MD="${HOME}/.claude/CLAUDE.md"
if [ -f "$CLAUDE_MD" ]; then
  claude_md_content=$(cat "$CLAUDE_MD")
  banned_found=0
  for term in gemini deepwiki codedb mgrep lazygit deep-research; do
    if printf '%s\n' "$claude_md_content" | grep -qi "$term"; then
      bad "banned term '$term' found in $CLAUDE_MD"
      banned_found=1
    fi
  done
  [ "$banned_found" -eq 0 ] && ok "no dead/banned tools found in $CLAUDE_MD"

  tools_missing=0
  for tool in fd rg bat eza dust procs btm xh delta hyperfine fff; do
    if ! printf '%s\n' "$claude_md_content" | grep -q "\b$tool\b"; then
      bad "required tool '$tool' not mentioned in $CLAUDE_MD"
      tools_missing=1
    fi
  done
  if ! printf '%s\n' "$claude_md_content" | grep -q "ast-grep" && ! printf '%s\n' "$claude_md_content" | grep -q "\bsg\b"; then
    bad "ast-grep/sg not mentioned in $CLAUDE_MD"
    tools_missing=1
  fi
  [ "$tools_missing" -eq 0 ] && ok "all required modern tools present in $CLAUDE_MD"
else
  na "$CLAUDE_MD does not exist"
fi

# ---------------------------------------------------------------------------
printf '\n%s: %d passed, %d failed, %d skipped\n' \
  "$(basename "$0")" "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
