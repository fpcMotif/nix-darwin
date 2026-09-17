---
name: lark-cli-setup
description: "Guide for installing, configuring, and querying Lark/Feishu Wiki and Docs via @larksuite/cli using bun."
---

# Lark CLI (Official Feishu/Lark CLI) Quick Operations

## Installation via Bun (without brew or npm)
```bash
# Wrap bunx @larksuite/cli into local path
mkdir -p ~/.local/bin
cat << 'EOF' > ~/.local/bin/lark-cli
#!/usr/bin/env bash
exec bunx @larksuite/cli "$@"
EOF
chmod +x ~/.local/bin/lark-cli
export PATH="$HOME/.local/bin:$PATH"
```

## Setup & Authorization
```bash
# 1. Check status
lark-cli whoami

# 2. Config & Login
lark-cli config init --new
lark-cli auth login --recommend
```

## Wiki & Document Operations
```bash
# List accessible spaces
lark-cli wiki +space-list

# Get node details from token or url
lark-cli wiki +node-get --node-token <NODE_TOKEN>

# List child nodes under a space / parent node
lark-cli wiki +node-list --space-id <SPACE_ID> --parent-node-token <PARENT_NODE_TOKEN>

# Fetch full document content as markdown
lark-cli docs +fetch --doc <OBJ_TOKEN> --doc-format markdown --jq '.data.document.content'
```
