#!/usr/bin/env bash
set -euo pipefail

claude_md="$1"
claude_nix="$2"

if [ ! -f "$claude_md" ]; then
  echo "claude-md-test: CLAUDE.md not found at '$claude_md'" >&2
  exit 1
fi

if [ ! -f "$claude_nix" ]; then
  echo "claude-md-test: claude.nix not found at '$claude_nix'" >&2
  exit 1
fi

content=$(cat "$claude_md")
nix_content=$(cat "$claude_nix")

# 1. Banned tools / references (case-insensitive)
banned_terms=(
  "gemini"
  "deepwiki"
  "codedb"
  "mgrep"
  "lazygit"
  "deep-research"
  "chezmoi"
)

for term in "${banned_terms[@]}"; do
  if printf '%s\n' "$content" | grep -qi "$term"; then
    echo "claude-md-test: FAIL banned term '$term' found in CLAUDE.md" >&2
    exit 1
  fi
done

# 2. Required installed tools presence
required_tools=(
  "fd"
  "rg"
  "bat"
  "eza"
  "dust"
  "procs"
  "btm"
  "xh"
  "delta"
  "hyperfine"
  "fff"
)

for tool in "${required_tools[@]}"; do
  if ! printf '%s\n' "$content" | grep -q "\b$tool\b"; then
    echo "claude-md-test: FAIL required tool '$tool' not found in CLAUDE.md" >&2
    exit 1
  fi
done

# Check ast-grep / sg
if ! printf '%s\n' "$content" | grep -q "ast-grep" && ! printf '%s\n' "$content" | grep -q "\bsg\b"; then
  echo "claude-md-test: FAIL ast-grep/sg not found in CLAUDE.md" >&2
  exit 1
fi

# 3. Required sections
required_sections=(
  "Identity"
  "Tooling defaults"
  "Search"
  "Git"
  "Code Quality"
  "Writing Style"
)

for section in "${required_sections[@]}"; do
  if ! printf '%s\n' "$content" | grep -qE "^##+ .*$section"; then
    echo "claude-md-test: FAIL required section '$section' not found in CLAUDE.md" >&2
    exit 1
  fi
done

# 4. claude.nix must bind to local ./claude/CLAUDE.md, not dotClaude template
if printf '%s\n' "$nix_content" | grep -qF 'dotClaude + "/claude.md.tmpl"'; then
  echo "claude-md-test: FAIL claude.nix still references dotClaude + \"/claude.md.tmpl\"" >&2
  exit 1
fi

if ! printf '%s\n' "$nix_content" | grep -qF '".claude/CLAUDE.md".source = ./claude/CLAUDE.md'; then
  echo "claude-md-test: FAIL claude.nix must bind \".claude/CLAUDE.md\".source = ./claude/CLAUDE.md" >&2
  exit 1
fi

echo "claude-md-test: PASS all assertions passed"
