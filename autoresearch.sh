#!/usr/bin/env bash
set -euo pipefail

# Repository-local maintainability signals for the Nix config. This is not a
# substitute for review; it catches documentation drift, check-contract gaps,
# and stale source-of-truth docs that make the repo harder to navigate.

count_missing_module_docs() {
  local count=0 file base
  while IFS= read -r file; do
    base=$(basename "$file")
    if ! grep -Fq "$base" ARCHITECTURE.md; then
      count=$((count + 1))
    fi
  done < <(find modules -mindepth 2 -maxdepth 2 -type f -name '*.nix' ! -name default.nix | sort)
  printf '%s\n' "$count"
}

count_test_attrs_missing_from_readme() {
  local count=0 attr
  while IFS= read -r attr; do
    if ! grep -Fq "\`$attr\`" tests/README.md; then
      count=$((count + 1))
    fi
  done < <(
    awk '
      /^[[:space:]]*[A-Za-z0-9_-]+[[:space:]]*=[[:space:]]*(callTest|pkgs\.runCommand)/ {
        name=$1; sub(/=.*/, "", name); gsub(/[[:space:]]/, "", name); print name
      }
    ' tests/default.nix | sort -u
  )
  printf '%s\n' "$count"
}

count_stale_readme_tests() {
  local count=0 attr
  while IFS= read -r attr; do
    if ! grep -Eq "^[[:space:]]*$attr[[:space:]]*=" tests/default.nix; then
      count=$((count + 1))
    fi
  done < <(
    awk -F'`' '/^\| `/ { print $2 }' tests/README.md | sort -u
  )
  printf '%s\n' "$count"
}

count_lint_contract_gaps() {
  local count=0
  if grep -Fq 'nixpkgs-fmt' ARCHITECTURE.md && ! grep -Rqs 'nixpkgs-fmt' tests; then
    count=$((count + 1))
  fi
  if grep -Fq 'statix' ARCHITECTURE.md && ! grep -Rqs 'statix' tests; then
    count=$((count + 1))
  fi
  if grep -Fq 'deadnix' ARCHITECTURE.md && ! grep -Rqs 'deadnix' tests; then
    count=$((count + 1))
  fi
  printf '%s\n' "$count"
}

count_long_nix_lines() {
  find . \
    -path './.git' -prune -o \
    -path './.claude' -prune -o \
    -path './references' -prune -o \
    -path './result*' -prune -o \
    -type f -name '*.nix' -print \
    | sort \
    | xargs awk 'length($0) > 140 { count++ } END { print count + 0 }'
}

count_nix_files() {
  find . \
    -path './.git' -prune -o \
    -path './.claude' -prune -o \
    -path './references' -prune -o \
    -path './result*' -prune -o \
    -type f -name '*.nix' -print \
    | wc -l \
    | tr -d '[:space:]'
}

count_stale_linting_policy() {
  if grep -Fq 'Add `statix`/`deadnix` as explicit checks before treating them as enforced gates' ARCHITECTURE.md; then
    printf '1\n'
  else
    printf '0\n'
  fi
}

count_missing_statix_policy_doc() {
  if [ -f statix.toml ] && ! grep -Fq 'statix.toml' ARCHITECTURE.md; then
    printf '1\n'
  else
    printf '0\n'
  fi
}

count_stale_review_date() {
  if grep -Fq '> **Last reviewed:** 2026-05-24.' ARCHITECTURE.md; then
    printf '0\n'
  else
    printf '1\n'
  fi
}

docs_missing_modules=$(count_missing_module_docs)
docs_missing_tests=$(count_test_attrs_missing_from_readme)
docs_stale_tests=$(count_stale_readme_tests)
lint_contract_gaps=$(count_lint_contract_gaps)
long_nix_lines=$(count_long_nix_lines)
nix_files=$(count_nix_files)
stale_linting_policy=$(count_stale_linting_policy)
missing_statix_policy_doc=$(count_missing_statix_policy_doc)
stale_review_date=$(count_stale_review_date)

quality_debt=$((docs_missing_modules * 10 + docs_missing_tests * 8 + docs_stale_tests * 8 + lint_contract_gaps * 25 + long_nix_lines))
doc_truth_debt=$((quality_debt + stale_linting_policy * 25 + missing_statix_policy_doc * 15 + stale_review_date * 10))

printf 'METRIC doc_truth_debt=%s\n' "$doc_truth_debt"
printf 'METRIC quality_debt=%s\n' "$quality_debt"
printf 'METRIC docs_missing_modules=%s\n' "$docs_missing_modules"
printf 'METRIC docs_missing_tests=%s\n' "$docs_missing_tests"
printf 'METRIC docs_stale_tests=%s\n' "$docs_stale_tests"
printf 'METRIC lint_contract_gaps=%s\n' "$lint_contract_gaps"
printf 'METRIC long_nix_lines=%s\n' "$long_nix_lines"
printf 'METRIC nix_files=%s\n' "$nix_files"
printf 'METRIC stale_linting_policy=%s\n' "$stale_linting_policy"
printf 'METRIC missing_statix_policy_doc=%s\n' "$missing_statix_policy_doc"
printf 'METRIC stale_review_date=%s\n' "$stale_review_date"
