#!/usr/bin/env bash
set -uo pipefail
WORKDIR="${1:?workdir}"
SINCE="${2:-$(date -v-2m +%Y-%m-%d 2>/dev/null || date -d '2 months ago' +%Y-%m-%d)}"
GH_USER="${3:-$(gh api user --jq .login 2>/dev/null || echo unknown)}"

skill_description() {
  awk '/^---/{fences++; next} fences==1 &&/^description:/{sub(/^description:[ ]*/,""); print; exit}' "$1" | tr -d '"' | cut -c1-200
}

# Per-root counts would break the markdown list, and stderr lands in inventory.log.
skill_section() {
  local label="$1" body
  body=$(while read -r f; do [ -f "$f" ] || continue; printf -- "- %s: %s\n" "$(basename "$(dirname "$f")")" "$(skill_description "$f")"; done | sort -u)
  echo; echo "## $label"; [ -n "$body" ] && echo "$body"
  echo "$label: $(printf '%s\n' "$body" | rg -c '^- ' || echo 0)" >&2
}

find_skill_files() { fd -H -t f '^SKILL\.md$' "$@" 2>/dev/null; }

# ~/.skillshub has its own section, and listing its links here would count those skills twice.
skills_outside_skillshub() {
  local link
  for link in ~/.claude/skills/* ~/.agents/skills/* ~/.codex/skills/*; do
    [ -e "$link/SKILL.md" ] || continue
    case "$(readlink -f "$link" 2>/dev/null || echo "$link")" in
      *skillshub*) ;;
      *) echo "$link/SKILL.md" ;;
    esac
  done | sort -u
}

write_installed_skills() {
  echo "# Installed agent skills on $(hostname -s), $(date +%Y-%m-%d) — every root, deduplicated by name within a root"
  find_skill_files ~/.skillshub | skill_section "skillshub (symlinked into ~/.claude/skills, ~/.agents/skills, ~/.codex/skills)"
  skills_outside_skillshub | skill_section "claude / agents / codex roots beyond skillshub (nix home-manager, local)"
  find_skill_files ~/.omp/agent/managed-skills | skill_section "OMP managed-skills (~/.omp/agent/managed-skills)"
  find_skill_files ~/.pi/agent/npm/node_modules ~/.pi/agent/git | rg -v 'examples/|skill-conflict-backups' | skill_section "pi packages (~/.pi/agent, from ~/.pi/agent/settings.json)"
  echo; echo "## pi packages declared in settings.json"; jq -r '.packages[] | if type=="string" then . else .source end' ~/.pi/agent/settings.json 2>/dev/null | sed 's/^/- /'
  { find_skill_files ~/.factory ~/.cursor/skills | rg -v '/node_modules/'; find_skill_files ~/.config/opencode; } | skill_section "factory / cursor / opencode"
  echo; echo "## Claude Code plugins enabled"; jq -r '.enabledPlugins | keys[]' ~/.claude/settings.json 2>/dev/null | sed 's/^/- /'
  fd -t f SKILL.md ~/.claude/plugins/cache 2>/dev/null | skill_section "Claude plugin skills"
}

write_gh_activity() {
  echo "# $GH_USER's own GitHub activity since $SINCE"; echo; echo "## Repos pushed in window"
  gh repo list "$GH_USER" --limit 300 --json name,pushedAt,createdAt,description,isPrivate,primaryLanguage,stargazerCount --jq ".[] | select(.pushedAt >= \"$SINCE\") | \"\(.pushedAt[0:10]) created=\(.createdAt[0:10]) \(.name) [\(.primaryLanguage.name // \"-\")] \(if .isPrivate then \"private\" else \"public\" end) ★\(.stargazerCount) :: \(.description // \"\")\"" 2>/dev/null | sort -r
  echo; echo "## Recent events (API keeps ~300)"
  gh api "users/$GH_USER/events?per_page=100" --paginate --jq ".[] | select(.created_at >= \"$SINCE\") | \"\(.created_at[0:10]) \(.type) \(.repo.name) :: \(.payload.pull_request.title // .payload.issue.title // .payload.ref // .payload.commits[0].message // \"\" | .[0:100])\"" 2>/dev/null | sort -r | uniq | head -150
  echo; echo "## Starred in window"
  gh api "users/$GH_USER/starred?per_page=100&sort=created" -H "Accept: application/vnd.github.star+json" --jq ".[] | select(.starred_at >= \"$SINCE\") | \"\(.starred_at[0:10]) \(.repo.full_name) ★\(.repo.stargazers_count) :: \(.repo.description // \"\" | .[0:100])\"" 2>/dev/null | head -100
}

write_installed_skills > "$WORKDIR/installed_skills.md" 2> "$WORKDIR/inventory.log"
write_gh_activity > "$WORKDIR/gh_activity.md"
echo "wrote $WORKDIR/installed_skills.md ($(rg -c '^- ' "$WORKDIR/installed_skills.md") skills across roots; per-root counts in $WORKDIR/inventory.log) and $WORKDIR/gh_activity.md ($(wc -l < "$WORKDIR/gh_activity.md") lines)"
