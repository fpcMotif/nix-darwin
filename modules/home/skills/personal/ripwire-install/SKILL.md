---
name: ripwire-install
description: Install and configure prebuilt ripwire binary and agent skills from redhat-et/ripwire with auth handling for GitHub API rate limits.
---

# Ripwire Install & Setup

Repeatable procedure for installing prebuilt `ripwire` releases from `redhat-et/ripwire` on macOS / Linux.

## Prerequisites & Edge Cases

1. **GitHub API Rate Limits (HTTP 403)**:
   The installer script queries `https://api.github.com/repos/redhat-et/ripwire/releases/latest`. On shared or unauthenticated environments, curl may receive HTTP 403 from GitHub's anonymous rate limiter.
   Resolve by wrapping curl to provide `Authorization: Bearer $(gh auth token 2>/dev/null)` when targeting `api.github.com` (do NOT provide this header to other domains such as AWS S3 asset download URLs).

2. **Non-interactive Execution**:
   The installer prompts `Proceed? [y/N]` unless `RIPWIRE_INSTALL_YES=1` is set. In automated or subshell contexts without `/dev/tty`, `RIPWIRE_INSTALL_YES=1` MUST be passed.

## Installation Procedure

```bash
TMP_BIN="$(mktemp -d)"
cat << 'EOF' > "$TMP_BIN/curl"
#!/usr/bin/env bash
token="$(gh auth token 2>/dev/null || true)"
has_github_api=0
for arg in "$@"; do
    if [[ "$arg" == *"api.github.com"* ]]; then
        has_github_api=1
    fi
done

if [ "$has_github_api" -eq 1 ] && [ -n "$token" ]; then
    exec /usr/bin/curl -H "Authorization: Bearer $token" "$@"
else
    exec /usr/bin/curl "$@"
fi
EOF
chmod +x "$TMP_BIN/curl"

PATH="$TMP_BIN:$PATH" RIPWIRE_REPO=redhat-et/ripwire RIPWIRE_INSTALL_YES=1 \
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/redhat-et/ripwire/main/scripts/install.sh)"

rm -rf "$TMP_BIN"
```

## Verification

```bash
ripwire --version
ripwire . --doctor
```

Confirm all doctor checks pass (`passed="7"`).
Skills are automatically staged at `~/.local/share/ripwire/skills` and symlinked to `~/.claude/skills` and `~/.agents/skills`.
