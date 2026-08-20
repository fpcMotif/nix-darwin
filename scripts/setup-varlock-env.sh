#!/usr/bin/env bash
# ==============================================================================
# setup-varlock-env.sh
# Configures a TypeScript/Vite/Bun project to use Varlock for type-safe envs
# while explicitly turning off ambient .env loading in mise and Bun.
# ==============================================================================
set -euo pipefail

TARGET_DIR="${1:-.}"
cd "$TARGET_DIR"

echo "🔧 Configuring Varlock environment management in $(pwd)..."

# 1. mise.toml — Disable ambient .env loading so mise only manages runtimes
if [ -f "mise.toml" ]; then
  if ! grep -q '_\.dotenv' mise.toml 2>/dev/null; then
    echo -e '\n[env]\n_.dotenv = false' >> mise.toml
    echo "  ✓ Updated mise.toml: disabled _.dotenv"
  else
    echo "  - mise.toml: already configured"
  fi
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

# 2. bunfig.toml — Disable Bun auto-loading of .env
if [ -f "bunfig.toml" ]; then
  if ! grep -q '\[env\]' bunfig.toml 2>/dev/null; then
    echo -e '\n[env]\nenv = false' >> bunfig.toml
    echo "  ✓ Updated bunfig.toml: disabled [env] env = false"
  else
    echo "  - bunfig.toml: already configured"
  fi
else
  cat << 'EOF' > bunfig.toml
[env]
# Prevent Bun from automatically reading .env without validation
env = false
EOF
  echo "  ✓ Created bunfig.toml with [env] env = false"
fi

# 3. .env.schema — Define Varlock schema & TypeScript generation target
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

# 4. .env.example — Provide template
if [ ! -f ".env.example" ]; then
  cat << 'EOF' > .env.example
NODE_ENV=development
VITE_API_URL=http://localhost:3000
VITE_SECRET_KEY=dev-secret-key-123
EOF
  echo "  ✓ Created .env.example"
fi

# Create initial .env from .env.example if missing
if [ ! -f ".env" ] && [ -f ".env.example" ]; then
  cp .env.example .env
  echo "  ✓ Created default .env from .env.example"
fi

# 5. .gitignore — Ensure secrets stay out of git
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

# 6. package.json scripts (if package.json exists)
if [ -f "package.json" ]; then
  if command -v jq >/dev/null 2>&1; then
    tmp=$(mktemp)
    jq '.scripts = (.scripts // {}) + {
      "prepare": "varlock codegen",
      "env:check": "varlock load",
      "env:scan": "varlock scan"
    }' package.json > "$tmp" && mv "$tmp" package.json
    echo "  ✓ Added Varlock scripts to package.json (prepare, env:check, env:scan)"
  fi
fi

# 7. tsconfig.json — Ensure env.d.ts is included in TypeScript checking
if [ -f "tsconfig.json" ]; then
  if command -v jq >/dev/null 2>&1; then
    tmp=$(mktemp)
    jq 'if .include then (.include = ((.include + ["env.d.ts"]) | unique)) else . end' tsconfig.json > "$tmp" && mv "$tmp" tsconfig.json
    echo "  ✓ Updated tsconfig.json to include env.d.ts"
  fi
fi

echo ""
echo "✨ Project configuration complete!"
echo "To install Varlock and generate your initial TypeScript definitions, run:"
echo ""
echo "  bun add -D varlock @varlock/vite-integration"
echo "  bun run prepare"
echo ""
