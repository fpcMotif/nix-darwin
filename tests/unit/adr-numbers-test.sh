#!/usr/bin/env bash
set -euo pipefail

adr_dir=$1

names=$(find "$adr_dir" -maxdepth 1 -type f -name '*.md' -exec basename {} \; | sort)
[ -n "$names" ] || {
  echo "docs/adr: no ADRs found in $adr_dir" >&2
  exit 1
}

# Docs and code cite an ADR by number (ADR-0008), so every ADR needs one.
unnumbered=$(printf '%s\n' "$names" | grep -vE '^[0-9]{4}-' || true)
if [ -n "$unnumbered" ]; then
  echo "docs/adr: every ADR name starts with a four-digit number and a dash:" >&2
  printf '  %s\n' $unnumbered >&2
  exit 1
fi

# Two ADRs sharing a number make every citation of that number ambiguous.
# Renumber the newer one past the highest number in git history, since a
# deleted ADR's number stays retired.
dupes=$(printf '%s\n' "$names" | cut -c1-4 | uniq -d)
if [ -n "$dupes" ]; then
  echo "docs/adr: ADR numbers must be unique; these share one:" >&2
  for number in $dupes; do
    printf '%s\n' "$names" | grep "^$number-" | while IFS= read -r name; do
      echo "  $name" >&2
    done
  done
  exit 1
fi
