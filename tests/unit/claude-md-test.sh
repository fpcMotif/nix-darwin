#!/usr/bin/env bash
set -euo pipefail

claude_md="$1"
claude_nix="$2"
human_documents="$3"
claude_development="$4"

for path in "$claude_md" "$claude_nix" "$human_documents" "$claude_development"; do
  if [ ! -f "$path" ]; then
    echo "claude-md-test: missing '$path'" >&2
    exit 1
  fi
done

content=$(cat "$claude_md")
nix_content=$(cat "$claude_nix")
documents_content=$(cat "$human_documents")
development_content=$(cat "$claude_development")
all_content=$(printf '%s\n%s\n' "$content" "$development_content")

banned_terms=(gemini deepwiki mgrep lazygit deep-research chezmoi)
for term in "${banned_terms[@]}"; do
  if printf '%s\n' "$all_content" | grep -qi "$term"; then
    echo "claude-md-test: banned term '$term' found" >&2
    exit 1
  fi
done

required_tools=(fd rg bat eza dust procs btm ax delta hyperfine fff)
for tool in "${required_tools[@]}"; do
  if ! printf '%s\n' "$all_content" | grep -q "\b$tool\b"; then
    echo "claude-md-test: required tool '$tool' missing" >&2
    exit 1
  fi
done

required_sections=(
  "Claude"
  "Working contract"
  "Completion"
  "Command routing"
  "Code search"
  "Python"
  "Version control"
  "Code quality"
  "Writing"
)
for section in "${required_sections[@]}"; do
  if ! printf '%s\n' "$all_content" | grep -qiE "^##+ .*$section"; then
    echo "claude-md-test: required section '$section' missing" >&2
    exit 1
  fi
done

for marker in "## Working contract" "## Command routing" "## Code quality" "## Testing" "## Waiting and background work"; do
  count=$(printf '%s\n' "$all_content" | grep -cF "$marker")
  if [ "$count" -ne 1 ]; then
    echo "claude-md-test: '$marker' must appear once, found $count" >&2
    exit 1
  fi
done

if ! printf '%s\n' "$content" | grep -qF '~/.claude/guidance/human-documents.md'; then
  echo "claude-md-test: human-document context pointer missing" >&2
  exit 1
fi
if ! printf '%s\n' "$content" | grep -qF '~/.claude/guidance/development.md'; then
  echo "claude-md-test: development context pointer missing" >&2
  exit 1
fi
if ! printf '%s\n' "$content" | grep -qF '~/.claude/guidance/testing.md'; then
  echo "claude-md-test: testing context pointer missing" >&2
  exit 1
fi
if ! printf '%s\n' "$documents_content" | grep -qF 'The document is done when'; then
  echo "claude-md-test: human-document completion criterion missing" >&2
  exit 1
fi

if printf '%s\n' "$nix_content" | grep -qF 'dotClaude + "/claude.md.tmpl"'; then
  echo "claude-md-test: legacy dotClaude template remains" >&2
  exit 1
fi
for binding in \
  'renderAgentGuide = import ./agent-instructions/render-agent-guide.nix' \
  '".claude/CLAUDE.md".source = claudeGuide;' \
  '".claude/guidance/development.md".source = claudeDevelopmentGuide;' \
  '".claude/guidance/human-documents.md".source = ./claude/human-documents.md;' \
  '".claude/guidance/testing.md".source = ./agent-instructions/shared/testing.md;'
do
  if ! printf '%s\n' "$nix_content" | grep -qF "$binding"; then
    echo "claude-md-test: missing Nix binding '$binding'" >&2
    exit 1
  fi
done

echo "claude-md-test: PASS"
