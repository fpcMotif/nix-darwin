#!/usr/bin/env bash
set -euo pipefail

adr_dir=$1

# docs/adr holds decision records only. A rendered page, export, or draft
# beside an ADR is a second copy of the decision that nothing keeps current.
stray=$(find "$adr_dir" -mindepth 1 ! \( -type f -name '*.md' \) | sort)
if [ -n "$stray" ]; then
  echo "docs/adr: only .md files belong here; remove or move:" >&2
  printf '%s\n' "$stray" | while IFS= read -r path; do
    echo "  ${path#"$adr_dir"/}" >&2
  done
  exit 1
fi

[ -n "$(find "$adr_dir" -maxdepth 1 -type f -name '*.md')" ] || {
  echo "docs/adr: no ADRs found in $adr_dir" >&2
  exit 1
}
