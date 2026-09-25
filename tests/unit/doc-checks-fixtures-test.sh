#!/usr/bin/env bash
set -euo pipefail

# Each docs check must pass a clean tree and fail a broken one, naming the
# offending file. A check that cannot fail guards nothing.
adr_files=$1
adr_numbers=$2
doc_links=$3

work=$(mktemp -d "${TMPDIR:-/tmp}/doc-checks-fixtures.XXXXXX")
trap 'rm -rf "$work"' EXIT

make_tree() {
  mkdir -p "$1/docs/adr" "$1/docs/agents"
  printf '# One\n' >"$1/docs/adr/0001-one.md"
  printf '# Two\n\nFollows [one](0001-one.md#context).\n' >"$1/docs/adr/0002-two.md"
  printf '%s\n' \
    '# Domain' \
    '[ADR](../adr/0002-two.md) ![image](<../adr/0001-one.md> "title")' \
    '[web](https://example.com/x.md) [mail](mailto:a@example.com) [anchor](#domain)' \
    'Inline code is not a link: `[x](inline-missing.md)`.' \
    '```' \
    '[fenced](fenced-missing.md)' \
    '```' \
    '[ref]: ../../AGENTS.md' >"$1/docs/agents/domain.md"
  printf '[domain](docs/agents/domain.md) [adr dir](docs/adr/) [root](/CONTEXT.md)\n' >"$1/AGENTS.md"
  touch "$1/ARCHITECTURE.md" "$1/CONTEXT.md"
}

expect_pass() {
  local name=$1
  shift
  "$@" >"$work/out" 2>&1 || {
    echo "FAIL $name: rejected the clean fixture:" >&2
    cat "$work/out" >&2
    exit 1
  }
}

expect_fail() {
  local name=$1 offender=$2
  shift 2
  if "$@" >"$work/out" 2>&1; then
    echo "FAIL $name: passed a fixture with $offender" >&2
    exit 1
  fi
  grep -qF "$offender" "$work/out" || {
    echo "FAIL $name: failed without naming $offender:" >&2
    cat "$work/out" >&2
    exit 1
  }
  echo "PASS $name rejects $offender"
}

fresh() {
  rm -rf "$work/tree"
  make_tree "$work/tree"
  echo "$work/tree"
}

tree=$(fresh)
expect_pass adr-files bash "$adr_files" "$tree/docs/adr"
expect_pass adr-numbers bash "$adr_numbers" "$tree/docs/adr"
expect_pass doc-links bash "$doc_links" "$tree"
echo "PASS clean fixture passes all three checks"

tree=$(fresh)
touch "$tree/docs/adr/0002-two.html"
expect_fail adr-files 0002-two.html bash "$adr_files" "$tree/docs/adr"

tree=$(fresh)
mkdir "$tree/docs/adr/assets"
expect_fail adr-files assets bash "$adr_files" "$tree/docs/adr"

tree=$(fresh)
printf '# Duplicate\n' >"$tree/docs/adr/0002-duplicate.md"
expect_fail adr-numbers 0002-duplicate.md bash "$adr_numbers" "$tree/docs/adr"

tree=$(fresh)
printf '# Unnumbered\n' >"$tree/docs/adr/unnumbered.md"
expect_fail adr-numbers unnumbered.md bash "$adr_numbers" "$tree/docs/adr"

tree=$(fresh)
printf '\nSee [gone](../adr/0009-gone.md).\n' >>"$tree/docs/agents/domain.md"
expect_fail doc-links 'docs/agents/domain.md:10: broken link to ../adr/0009-gone.md' \
  bash "$doc_links" "$tree"

tree=$(fresh)
printf '[moved](docs/moved.md)\n' >>"$tree/AGENTS.md"
expect_fail doc-links 'AGENTS.md:2: broken link to docs/moved.md' bash "$doc_links" "$tree"

tree=$(fresh)
printf '[old]: docs/old.md\n' >>"$tree/CONTEXT.md"
expect_fail doc-links 'CONTEXT.md:1: broken link to docs/old.md' bash "$doc_links" "$tree"

tree=$(fresh)
rm "$tree/CONTEXT.md"
expect_fail doc-links 'CONTEXT.md is missing' bash "$doc_links" "$tree"
