#!/usr/bin/env bash
# mise and Bun each load .env on their own and skip Varlock's validation.
set -euo pipefail

TARGET_DIR="${1:-.}"
cd "$TARGET_DIR"

# Edits KEY inside an existing [TABLE] rather than appending, because a second
# [TABLE] header makes the file invalid TOML.
set_toml_key_false() {
  local file=$1 table=$2 key=$3 tmp
  tmp=$(mktemp)
  if ! awk -v table="$table" -v key="$key" '
    function header_name(line) {
      if (line !~ /^[ \t]*\[[^][]+\][ \t]*(#.*)?$/) return ""
      sub(/^[ \t]*\[[ \t]*/, "", line); sub(/[ \t]*\].*$/, "", line)
      return line
    }
    function is_key(line,   rest) {
      sub(/^[ \t]*/, "", line)
      if (substr(line, 1, length(key)) != key) return 0
      rest = substr(line, length(key) + 1)
      return rest ~ /^[ \t]*=/
    }
    NR == FNR {
      name = header_name($0)
      if (name != "") section = name
      else if (section == table && is_key($0)) has_key = 1
      if (name == table) has_table = 1
      next
    }
    {
      name = header_name($0)
      if (name != "") section = name
      if (section == table && name == "" && is_key($0)) { print key " = false"; next }
      print
      if (name == table && !has_key) print key " = false"
    }
    END { if (!has_table) printf "\n[%s]\n%s = false\n", table, key }
  ' "$file" "$file" > "$tmp"; then
    rm -f "$tmp"
    echo "  ✗ $file: could not set [$table] $key = false; left unchanged" >&2
    return 1
  fi
  if cmp -s "$tmp" "$file"; then
    rm -f "$tmp"
    echo "  - $file: already configured"
  else
    mv "$tmp" "$file"
    echo "  ✓ Updated $file: set [$table] $key = false"
  fi
}

configure_mise() {
  if [ -f "mise.toml" ]; then
    set_toml_key_false mise.toml env _.dotenv
  else
    cat << 'EOF' > mise.toml
[tools]
node = "22"
bun = "latest"

[env]
# Disable ambient .env loading so Varlock owns environment validation
_.dotenv = false
EOF
    echo "  ✓ Created mise.toml with _.dotenv = false"
  fi
}

configure_bunfig() {
  if [ -f "bunfig.toml" ]; then
    set_toml_key_false bunfig.toml env env
  else
    cat << 'EOF' > bunfig.toml
[env]
# Prevent Bun from automatically reading .env without validation
env = false
EOF
    echo "  ✓ Created bunfig.toml with [env] env = false"
  fi
}

write_env_schema() {
  if [ ! -f ".env.schema" ]; then
    cat << 'EOF' > .env.schema
# @defaultRequired=false @defaultSensitive=false
# @generateTsTypes(path=env.d.ts)
# ------------------------------------------------------------------------------

# Application Environment (development | staging | production)
# @type=enum(development, staging, production)
NODE_ENV=development

# Frontend Public API URL
# @type=url
VITE_API_URL=http://localhost:3000

# Sensitive secret (kept out of client bundles)
# @sensitive
VITE_SECRET_KEY=
EOF
    echo "  ✓ Created .env.schema"
  else
    echo "  - .env.schema: already exists"
  fi
}

write_env_example_and_default_env() {
  if [ ! -f ".env.example" ]; then
    cat << 'EOF' > .env.example
NODE_ENV=development
VITE_API_URL=http://localhost:3000
VITE_SECRET_KEY=dev-secret-key-123
EOF
    echo "  ✓ Created .env.example"
  fi

  if [ ! -f ".env" ] && [ -f ".env.example" ]; then
    cp .env.example .env
    echo "  ✓ Created default .env from .env.example"
  fi
}

ignore_env_files_in_git() {
  if [ -f ".gitignore" ]; then
    if ! grep -q '^\.env$' .gitignore 2>/dev/null; then
      echo -e '\n# Environment files\n.env\n.env.local\n.env.*.local\n!.env.example\n!.env.schema' >> .gitignore
      echo "  ✓ Updated .gitignore"
    fi
  else
    cat << 'EOF' > .gitignore
.env
.env.local
.env.*.local
!.env.example
!.env.schema
node_modules
dist
EOF
    echo "  ✓ Created .gitignore"
  fi
}

# Compares parsed JSON, because jq reformats the file even when no value changes.
rewrite_json_with_jq() {
  local file=$1 filter=$2 changed_message=$3 tmp
  tmp=$(mktemp)
  if ! jq "$filter" "$file" > "$tmp"; then
    rm -f "$tmp"
    echo "  ✗ $file: jq failed; left unchanged" >&2
    return 1
  fi
  if jq -e -n --slurpfile old "$file" --slurpfile new "$tmp" '$old == $new' >/dev/null; then
    rm -f "$tmp"
    echo "  - $file: already configured"
  else
    mv "$tmp" "$file"
    echo "  ✓ $changed_message"
  fi
}

add_varlock_package_scripts() {
  if [ -f "package.json" ] && command -v jq >/dev/null 2>&1; then
    rewrite_json_with_jq package.json '.scripts = (.scripts // {}) + {
      "prepare": "varlock codegen",
      "env:check": "varlock load",
      "env:scan": "varlock scan"
    }' "Added Varlock scripts to package.json (prepare, env:check, env:scan)"
  fi
}

include_env_types_in_tsconfig() {
  if [ -f "tsconfig.json" ] && command -v jq >/dev/null 2>&1; then
    rewrite_json_with_jq tsconfig.json 'if .include and (.include | index("env.d.ts") | not) then .include += ["env.d.ts"] else . end' \
      "Updated tsconfig.json to include env.d.ts"
  fi
}

echo "🔧 Configuring Varlock environment management in $(pwd)..."

configure_mise
configure_bunfig
write_env_schema
write_env_example_and_default_env
ignore_env_files_in_git
add_varlock_package_scripts
include_env_types_in_tsconfig

echo ""
echo "✨ Project configuration complete!"
echo "To install Varlock and generate your initial TypeScript definitions, run:"
echo ""
echo "  bun add -D varlock @varlock/vite-integration"
echo "  bun run prepare"
echo ""
