#!/usr/bin/env bash
# Writes installed_skills.md and gh_activity.md into $1 (work dir) for the skill-gap phase.
# Scans every agent skill root on this machine, not only ~/.claude/skills:
#   ~/.skillshub (source of the skills.sh + nix symlink farm), ~/.claude/skills, ~/.agents/skills, ~/.codex/skills,
#   ~/.omp/agent/managed-skills (OMP-managed, session-authored), ~/.pi/agent (npm/git packages from settings.json),
#   ~/.factory, ~/.cursor/skills, ~/.config/opencode, plus Claude plugins.
# usage: inventory.sh WORKDIR [SINCE=YYYY-MM-DD] [GH_USER]
set -uo pipefail
W="${1:?workdir}"; SINCE="${2:-$(date -v-2m +%Y-%m-%d 2>/dev/null || date -d '2 months ago' +%Y-%m-%d)}"; U="${3:-$(gh api user --jq .login 2>/dev/null || echo unknown)}"
desc() { awk '/^---/{c++; next} c==1 && /^description:/{sub(/^description:[ ]*/,""); print; exit}' "$1" | tr -d '"' | cut -c1-200; }
section() { # $1 label, then SKILL.md paths on stdin
  local label="$1" body
  body=$(while read -r f; do [ -f "$f" ] || continue; printf -- "- %s: %s\n" "$(basename "$(dirname "$f")")" "$(desc "$f")"; done | sort -u)
  echo; echo "## $label"; [ -n "$body" ] && echo "$body"
  echo "$label: $(printf '%s\n' "$body" | rg -c '^- ' || echo 0)" >&2
}
{
  echo "# Installed agent skills on $(hostname -s), $(date +%Y-%m-%d) — every root, deduplicated by name within a root"
  fd -H -t f '^SKILL\.md$' ~/.skillshub 2>/dev/null | section "skillshub (symlinked into ~/.claude/skills, ~/.agents/skills, ~/.codex/skills)"
  for l in ~/.claude/skills/* ~/.agents/skills/* ~/.codex/skills/*; do [ -e "$l/SKILL.md" ] && case "$(readlink -f "$l" 2>/dev/null || echo "$l")" in *skillshub*) ;; *) echo "$l/SKILL.md";; esac; done | sort -u | section "claude / agents / codex roots beyond skillshub (nix home-manager, local)"
  fd -H -t f '^SKILL\.md$' ~/.omp/agent/managed-skills 2>/dev/null | section "OMP managed-skills (~/.omp/agent/managed-skills)"
  fd -H -t f '^SKILL\.md$' ~/.pi/agent/npm/node_modules ~/.pi/agent/git 2>/dev/null | rg -v 'examples/|skill-conflict-backups' | section "pi packages (~/.pi/agent, from ~/.pi/agent/settings.json)"
  echo; echo "## pi packages declared in settings.json"; jq -r '.packages[] | if type=="string" then . else .source end' ~/.pi/agent/settings.json 2>/dev/null | sed 's/^/- /'
  { fd -H -t f '^SKILL\.md$' ~/.factory ~/.cursor/skills 2>/dev/null | rg -v '/node_modules/'; fd -H -t f '^SKILL\.md$' ~/.config/opencode 2>/dev/null; } | section "factory / cursor / opencode"
  echo; echo "## Claude Code plugins enabled"; jq -r '.enabledPlugins | keys[]' ~/.claude/settings.json 2>/dev/null | sed 's/^/- /'
  fd -t f SKILL.md ~/.claude/plugins/cache 2>/dev/null | section "Claude plugin skills"
} > "$W/installed_skills.md" 2> "$W/inventory.log"
{
  echo "# $U's own GitHub activity since $SINCE"; echo; echo "## Repos pushed in window"
  gh repo list "$U" --limit 300 --json name,pushedAt,createdAt,description,isPrivate,primaryLanguage,stargazerCount --jq ".[] | select(.pushedAt >= \"$SINCE\") | \"\(.pushedAt[0:10]) created=\(.createdAt[0:10]) \(.name) [\(.primaryLanguage.name // \"-\")] \(if .isPrivate then \"private\" else \"public\" end) ★\(.stargazerCount) :: \(.description // \"\")\"" 2>/dev/null | sort -r
  echo; echo "## Recent events (API keeps ~300)"
  gh api "users/$U/events?per_page=100" --paginate --jq ".[] | select(.created_at >= \"$SINCE\") | \"\(.created_at[0:10]) \(.type) \(.repo.name) :: \(.payload.pull_request.title // .payload.issue.title // .payload.ref // .payload.commits[0].message // \"\" | .[0:100])\"" 2>/dev/null | sort -r | uniq | head -150
  echo; echo "## Starred in window"
  gh api "users/$U/starred?per_page=100&sort=created" -H "Accept: application/vnd.github.star+json" --jq ".[] | select(.starred_at >= \"$SINCE\") | \"\(.starred_at[0:10]) \(.repo.full_name) ★\(.repo.stargazers_count) :: \(.repo.description // \"\" | .[0:100])\"" 2>/dev/null | head -100
} > "$W/gh_activity.md"
echo "wrote $W/installed_skills.md ($(rg -c '^- ' "$W/installed_skills.md") skills across roots; per-root counts in $W/inventory.log) and $W/gh_activity.md ($(wc -l < "$W/gh_activity.md") lines)"
