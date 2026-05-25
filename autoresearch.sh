#!/usr/bin/env bash
set -euo pipefail

# Repository-local maintainability signals for the Nix config. This is not a
# substitute for review; it catches documentation drift, check-contract gaps,
# stale source-of-truth docs, and missing guidance that would make a resumed
# autoresearch loop less realistic or more likely to overfit.

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

section_exists() {
  grep -Fxq "$1" autoresearch.md
}

section_has_body() {
  awk -v heading="$1" '
    $0 == heading { in_section = 1; next }
    in_section && /^## / { exit }
    in_section && $0 !~ /^[[:space:]]*$/ && $0 !~ /^<!--/ { found = 1; exit }
    END { exit(found ? 0 : 1) }
  ' autoresearch.md
}

count_guidance_sections() {
  local mode=$1 count=0 heading
  local required_sections=(
    '## Current Beliefs'
    '## Assumptions to Re-check'
    '## Search Goals'
    '## Hypotheses Backlog'
    '## Experiment Queue'
    '## Recursive/Delegated Review Plan'
    '## Realism Guardrails'
  )

  for heading in "${required_sections[@]}"; do
    if ! section_exists "$heading"; then
      if [ "$mode" = missing ]; then
        count=$((count + 1))
      fi
    elif ! section_has_body "$heading"; then
      if [ "$mode" = empty ]; then
        count=$((count + 1))
      fi
    fi
  done

  printf '%s\n' "$count"
}

count_option_docs() {
  python3 - "$1" <<'PY'
import sys
from pathlib import Path

mode = sys.argv[1]
count = 0
for path in sorted(Path("modules").rglob("*.nix")):
    text = path.read_text()
    cursor = 0
    while True:
        idx = text.find("lib.mkOption {", cursor)
        if idx == -1:
            break

        start = text.find("{", idx)
        depth = 0
        end = None
        for pos, char in enumerate(text[start:], start):
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    end = pos + 1
                    break

        block = text[idx:end] if end is not None else text[idx:]
        if mode == "total":
            count += 1
        elif mode == "missing_description" and "description =" not in block:
            count += 1
        elif mode == "missing_example" and "example =" not in block:
            count += 1

        cursor = end if end is not None else idx + 1

print(count)
PY
}

count_just_check_missing_test_attrs() {
  python3 <<'PY'
import re
from pathlib import Path

def check_attrs():
    attrs = []
    pattern = re.compile(r"^\s*([A-Za-z0-9_-]+)\s*=\s*(?:callTest|pkgs\.runCommand)")
    for line in Path("tests/default.nix").read_text().splitlines():
        match = pattern.match(line)
        if match:
            attrs.append(match.group(1))
    return attrs

def just_check_recipe():
    lines = Path("justfile").read_text().splitlines()
    block = []
    in_recipe = False
    for line in lines:
        if re.match(r"^check:", line):
            in_recipe = True
            block.append(line)
            continue
        if in_recipe and line and not line[0].isspace() and not line.startswith("#"):
            break
        if in_recipe:
            block.append(line)
    return "\n".join(block)

recipe = just_check_recipe()
if "nix flake check" in recipe:
    print(0)
else:
    print(sum(1 for attr in check_attrs() if attr not in recipe))
PY
}

count_autoresearch_missing_focused_checks() {
  python3 <<'PY'
import re
from pathlib import Path

attrs = []
pattern = re.compile(r"^\s*([A-Za-z0-9_-]+)\s*=\s*(?:callTest|pkgs\.runCommand)")
for line in Path("tests/default.nix").read_text().splitlines():
    match = pattern.match(line)
    if match and match.group(1).startswith(("unit-", "integration-")):
        attrs.append(match.group(1))

checks = Path("autoresearch.checks.sh").read_text()
print(sum(1 for attr in attrs if attr not in checks))
PY
}

count_just_check_missing_darwin_build() {
  if awk '/^check:/ { in_check = 1 } in_check && /^[^[:space:]#]/ && !/^check:/ { exit } in_check { print }' justfile \
    | grep -Fq 'darwinConfigurations.f.system'; then
    printf '0\n'
  else
    printf '1\n'
  fi
}

count_ci_missing_flake_check() {
  if grep -Fq 'nix flake check' .github/workflows/build.yml; then
    printf '0\n'
  else
    printf '1\n'
  fi
}

count_ci_missing_system_builds() {
  local count=0 config

  if ! grep -Fq 'darwinConfigurations.f.system' .github/workflows/build.yml; then
    count=$((count + 1))
  fi

  for config in wsl x230 vm-aarch64-utm; do
    if ! grep -Fq "$config" .github/workflows/build.yml; then
      count=$((count + 1))
    fi
  done

  printf '%s\n' "$count"
}

count_missing_behavioral_assertions() {
  python3 <<'PY'
import re
from pathlib import Path

required = [
    "darwin-rime-enabled",
    "darwin-rime-squirrel-system-package",
    "darwin-rime-post-activation",
    "darwin-rime-user-activation",
    "darwin-ghostty-generated-config",
    "darwin-ghostty-custom-theme-file",
    "darwin-bettermouse-seed-activation",
    "darwin-bettermouse-launchd-agents",
]

text = Path("tests/integration/configurations-eval-test.nix").read_text()
assertions = set(re.findall(r'helpers\.assertTest\s+"([^"]+)"', text))
print(sum(1 for name in required if name not in assertions))
PY
}

count_activation_path_duplicate_literals() {
  python3 <<'PY'
from pathlib import Path

tracked_literals = {
    "modules/darwin/mouse-display.nix": [
        "${currentSystemUserHome}/Library/Application Support/BetterMouse",
    ],
    "modules/darwin/rime.nix": [
        "${currentSystemUserHome}/Library/Rime",
        "/Library/Input Methods",
    ],
}

debt = 0
for filename, literals in tracked_literals.items():
    source = "\n".join(
        line
        for line in Path(filename).read_text().splitlines()
        if not line.lstrip().startswith("#")
    )
    for literal in literals:
        count = source.count(literal)
        if count > 1:
            debt += count - 1

print(debt)
PY
}

count_missing_claude_activation_assertions() {
  python3 <<'PY'
import re
from pathlib import Path

required = [
    "darwin-claude-managed-files",
    "darwin-claude-settings-seed-activation",
    "darwin-claude-stop-hook-debug-activation",
    "darwin-claude-disable-grill-skills-activation",
    "darwin-claude-disable-superpowers-brainstorming-activation",
]

text = Path("tests/integration/configurations-eval-test.nix").read_text()
assertions = set(re.findall(r'helpers\.assertTest\s+"([^"]+)"', text))
print(sum(1 for name in required if name not in assertions))
PY
}

count_stale_agent_skills_activation_claim() {
  if grep -Fq 'no custom activation scripts' ARCHITECTURE.md \
    && grep -Fq 'home.activation.' modules/home/claude.nix; then
    printf '1\n'
  else
    printf '0\n'
  fi
}

count_claude_main_activation_blocks() {
  if [ -f modules/home/claude.nix ]; then
    grep -c 'home\.activation\.claude' modules/home/claude.nix || true
  else
    printf '0\n'
  fi
}

count_missing_claude_split_modules() {
  local count=0 file
  for file in modules/home/claude-common.nix modules/home/claude-activations.nix; do
    if [ ! -f "$file" ]; then
      count=$((count + 1))
    fi
  done
  printf '%s\n' "$count"
}

count_stale_agent_skills_report_claims() {
  python3 <<'PY'
from pathlib import Path

report = Path("AGENT_SKILLS_NIX_REPORT.md")
if not report.exists():
    print(0)
    raise SystemExit

text = report.read_text()
stale_patterns = [
    "Live file: `modules/home/claude.nix`.",
    "modules/home/skills.nix` now uses the upstream Home Manager DSL",
    "Recommendation: keep `programs.agent-skills` plus `symlink-tree` global targets.",
    'structure = "symlink-tree"',
    "Reason: this Windows environment does not have `nix`, `nixpkgs-fmt`, or `nixfmt` available",
]

print(sum(1 for pattern in stale_patterns if pattern in text))
PY
}

count_stale_root_fallback_claims() {
  local count=0

  if [ ! -f skills.nix ] && grep -Fq 'skills.nix' ARCHITECTURE.md; then
    count=$((count + 1))
  fi

  if [ ! -f skills.nix ] && grep -Fq 'home.nix` and `skills.nix` exist' ARCHITECTURE.md; then
    count=$((count + 1))
  fi

  printf '%s\n' "$count"
}

count_stale_architecture_agent_target_policy_claims() {
  local count=0

  if grep -Fq 'structure = "link"' modules/home/claude.nix \
    && grep -Fq 'Use **`symlink-tree`** for global Home Manager targets.' ARCHITECTURE.md; then
    count=$((count + 1))
  fi

  if grep -Fq 'structure = "link"' modules/home/claude.nix \
    && grep -Fq 'Each enabled target uses rsync with deletion semantics' ARCHITECTURE.md; then
    count=$((count + 1))
  fi

  if grep -Fq 'excludePatterns = [ ];' modules/home/claude.nix \
    && grep -Fq 'Keep `excludePatterns = [ "/.system" ]` unless' ARCHITECTURE.md; then
    count=$((count + 1))
  fi

  printf '%s\n' "$count"
}

count_hotkeys_missing_repo_shortcut_files() {
  python3 <<'PY'
from pathlib import Path

doc = Path("HOTKEYS.md")
if not doc.exists():
    print(0)
    raise SystemExit

missing = 0
for line in doc.read_text().splitlines():
    line = line.strip()
    if not line.startswith("- `") or "personal-settings-main/" not in line:
        continue
    path = line.split("`", 2)[1]
    if "*" in path:
        parent = Path(path.split("*", 1)[0]).parent
        if not parent.exists():
            missing += 1
    elif not Path(path).exists():
        missing += 1

print(missing)
PY
}

count_hotkeys_missing_tmux_copy_mode_bindings() {
  python3 <<'PY'
from pathlib import Path

tmux = Path("modules/home/tmux.nix").read_text()
hotkeys = Path("HOTKEYS.md").read_text()

required = [
    ("bind -T copy-mode-vi q", "copy-mode `q`"),
    ("bind -T copy-mode-vi v", "copy-mode `v`"),
    ("bind -T copy-mode-vi V", "copy-mode `V`"),
    ("bind -T copy-mode-vi 'C-v'", "copy-mode `ctrl+v`"),
    ("bind -T copy-mode-vi y", "copy-mode `y`"),
    ("bind -T copy-mode-vi MouseDragEnd1Pane", "copy-mode mouse drag"),
    ("bind -T copy-mode-vi 'C-h'", "copy-mode `ctrl+h/j/k/l`"),
    ("bind -T copy-mode-vi 'C-\\\\'", "copy-mode `ctrl+\\`"),
    ("bind -T copy-mode-vi 'C-Space'", "copy-mode `ctrl+space`"),
]

print(sum(1 for module_pattern, doc_token in required if module_pattern in tmux and doc_token not in hotkeys))
PY
}

count_agent_report_link_policy_inconsistencies() {
  python3 <<'PY'
from pathlib import Path

module = Path("modules/home/claude.nix").read_text()
report_path = Path("AGENT_SKILLS_NIX_REPORT.md")
if not report_path.exists() or 'structure = "link"' not in module:
    print(0)
    raise SystemExit

report = report_path.read_text()
patterns = [
    "For these skill targets, `symlink-tree` is usually safer",
    "`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills`",
    "`${CODEX_HOME:-$HOME/.codex}/skills`",
    "Handles `$HOME`, `${CLAUDE_CONFIG_DIR:-...}`, `${CODEX_HOME:-...}`, and custom paths.",
    "| `symlink-tree` activation | Home Manager-native activation, not pure option-only linking | Yes | Yes, destination dir can be writable | Best global skills default. |",
    "### Why keep `symlink-tree` if it still makes symlinks?",
]

print(sum(1 for pattern in patterns if pattern in report))
PY
}

count_architecture_agent_static_target_inconsistencies() {
  python3 <<'PY'
from pathlib import Path

module = Path("modules/home/claude.nix").read_text()
common = Path("modules/home/claude-common.nix").read_text()
architecture = Path("ARCHITECTURE.md").read_text()

if 'structure = "link"' not in module:
    print(0)
    raise SystemExit

required_static_dirs = [
    'claude = ".claude/skills";',
    'codex = ".codex/skills";',
]
if any(pattern not in common for pattern in required_static_dirs):
    print(0)
    raise SystemExit

patterns = [
    "`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills`",
    "`${CODEX_HOME:-$HOME/.codex}/skills`",
]

print(sum(1 for pattern in patterns if pattern in architecture))
PY
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
guidance_missing_sections=$(count_guidance_sections missing)
guidance_empty_sections=$(count_guidance_sections empty)
option_total=$(count_option_docs total)
option_missing_descriptions=$(count_option_docs missing_description)
option_missing_examples=$(count_option_docs missing_example)
just_check_missing_test_attrs=$(count_just_check_missing_test_attrs)
autoresearch_missing_focused_checks=$(count_autoresearch_missing_focused_checks)
just_check_missing_darwin_build=$(count_just_check_missing_darwin_build)
ci_missing_flake_check=$(count_ci_missing_flake_check)
ci_missing_system_builds=$(count_ci_missing_system_builds)
missing_behavioral_assertions=$(count_missing_behavioral_assertions)
required_behavioral_assertions=8
activation_path_duplicate_literals=$(count_activation_path_duplicate_literals)
missing_claude_activation_assertions=$(count_missing_claude_activation_assertions)
required_claude_activation_assertions=5
stale_agent_skills_activation_claim=$(count_stale_agent_skills_activation_claim)
claude_main_activation_blocks=$(count_claude_main_activation_blocks)
missing_claude_split_modules=$(count_missing_claude_split_modules)
stale_agent_skills_report_claims=$(count_stale_agent_skills_report_claims)
stale_root_fallback_claims=$(count_stale_root_fallback_claims)
stale_architecture_agent_target_policy_claims=$(count_stale_architecture_agent_target_policy_claims)
hotkeys_missing_repo_shortcut_files=$(count_hotkeys_missing_repo_shortcut_files)
hotkeys_missing_tmux_copy_mode_bindings=$(count_hotkeys_missing_tmux_copy_mode_bindings)
agent_report_link_policy_inconsistencies=$(count_agent_report_link_policy_inconsistencies)
architecture_agent_static_target_inconsistencies=$(count_architecture_agent_static_target_inconsistencies)

quality_debt=$((docs_missing_modules * 10 + docs_missing_tests * 8 + docs_stale_tests * 8 + lint_contract_gaps * 25 + long_nix_lines))
doc_truth_debt=$((quality_debt + stale_linting_policy * 25 + missing_statix_policy_doc * 15 + stale_review_date * 10))
loop_guidance_debt=$((doc_truth_debt + guidance_missing_sections * 10 + guidance_empty_sections * 5))
option_doc_debt=$((loop_guidance_debt + option_missing_descriptions * 10 + option_missing_examples * 2))
check_parity_debt=$((option_doc_debt + just_check_missing_test_attrs * 3 + autoresearch_missing_focused_checks * 8 + just_check_missing_darwin_build * 10 + ci_missing_flake_check * 20 + ci_missing_system_builds * 10))
behavioral_coverage_debt=$((check_parity_debt + missing_behavioral_assertions * 5))
activation_path_literal_debt=$((behavioral_coverage_debt + activation_path_duplicate_literals * 4))
claude_activation_coverage_debt=$((activation_path_literal_debt + missing_claude_activation_assertions * 5))
agent_docs_truth_debt=$((claude_activation_coverage_debt + stale_agent_skills_activation_claim * 15))
claude_activation_locality_debt=$((agent_docs_truth_debt + claude_main_activation_blocks * 5 + missing_claude_split_modules * 5))
agent_report_truth_debt=$((claude_activation_locality_debt + stale_agent_skills_report_claims * 5))
root_fallback_docs_debt=$((agent_report_truth_debt + stale_root_fallback_claims * 10))
architecture_agent_policy_debt=$((root_fallback_docs_debt + stale_architecture_agent_target_policy_claims * 8))
hotkeys_repo_shortcut_docs_debt=$((architecture_agent_policy_debt + hotkeys_missing_repo_shortcut_files * 3))
hotkeys_active_binding_docs_debt=$((hotkeys_repo_shortcut_docs_debt + hotkeys_missing_tmux_copy_mode_bindings * 2))
agent_report_link_policy_debt=$((hotkeys_active_binding_docs_debt + agent_report_link_policy_inconsistencies * 4))
architecture_agent_static_target_debt=$((agent_report_link_policy_debt + architecture_agent_static_target_inconsistencies * 4))

printf 'METRIC architecture_agent_static_target_debt=%s\n' "$architecture_agent_static_target_debt"
printf 'METRIC agent_report_link_policy_debt=%s\n' "$agent_report_link_policy_debt"
printf 'METRIC hotkeys_active_binding_docs_debt=%s\n' "$hotkeys_active_binding_docs_debt"
printf 'METRIC hotkeys_repo_shortcut_docs_debt=%s\n' "$hotkeys_repo_shortcut_docs_debt"
printf 'METRIC architecture_agent_policy_debt=%s\n' "$architecture_agent_policy_debt"
printf 'METRIC root_fallback_docs_debt=%s\n' "$root_fallback_docs_debt"
printf 'METRIC agent_report_truth_debt=%s\n' "$agent_report_truth_debt"
printf 'METRIC claude_activation_locality_debt=%s\n' "$claude_activation_locality_debt"
printf 'METRIC agent_docs_truth_debt=%s\n' "$agent_docs_truth_debt"
printf 'METRIC claude_activation_coverage_debt=%s\n' "$claude_activation_coverage_debt"
printf 'METRIC activation_path_literal_debt=%s\n' "$activation_path_literal_debt"
printf 'METRIC behavioral_coverage_debt=%s\n' "$behavioral_coverage_debt"
printf 'METRIC check_parity_debt=%s\n' "$check_parity_debt"
printf 'METRIC option_doc_debt=%s\n' "$option_doc_debt"
printf 'METRIC loop_guidance_debt=%s\n' "$loop_guidance_debt"
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
printf 'METRIC guidance_missing_sections=%s\n' "$guidance_missing_sections"
printf 'METRIC guidance_empty_sections=%s\n' "$guidance_empty_sections"
printf 'METRIC option_total=%s\n' "$option_total"
printf 'METRIC option_missing_descriptions=%s\n' "$option_missing_descriptions"
printf 'METRIC option_missing_examples=%s\n' "$option_missing_examples"
printf 'METRIC just_check_missing_test_attrs=%s\n' "$just_check_missing_test_attrs"
printf 'METRIC autoresearch_missing_focused_checks=%s\n' "$autoresearch_missing_focused_checks"
printf 'METRIC just_check_missing_darwin_build=%s\n' "$just_check_missing_darwin_build"
printf 'METRIC ci_missing_flake_check=%s\n' "$ci_missing_flake_check"
printf 'METRIC ci_missing_system_builds=%s\n' "$ci_missing_system_builds"
printf 'METRIC missing_behavioral_assertions=%s\n' "$missing_behavioral_assertions"
printf 'METRIC required_behavioral_assertions=%s\n' "$required_behavioral_assertions"
printf 'METRIC activation_path_duplicate_literals=%s\n' "$activation_path_duplicate_literals"
printf 'METRIC missing_claude_activation_assertions=%s\n' "$missing_claude_activation_assertions"
printf 'METRIC required_claude_activation_assertions=%s\n' "$required_claude_activation_assertions"
printf 'METRIC stale_agent_skills_activation_claim=%s\n' "$stale_agent_skills_activation_claim"
printf 'METRIC claude_main_activation_blocks=%s\n' "$claude_main_activation_blocks"
printf 'METRIC missing_claude_split_modules=%s\n' "$missing_claude_split_modules"
printf 'METRIC stale_agent_skills_report_claims=%s\n' "$stale_agent_skills_report_claims"
printf 'METRIC stale_root_fallback_claims=%s\n' "$stale_root_fallback_claims"
printf 'METRIC stale_architecture_agent_target_policy_claims=%s\n' "$stale_architecture_agent_target_policy_claims"
printf 'METRIC hotkeys_missing_repo_shortcut_files=%s\n' "$hotkeys_missing_repo_shortcut_files"
printf 'METRIC hotkeys_missing_tmux_copy_mode_bindings=%s\n' "$hotkeys_missing_tmux_copy_mode_bindings"
printf 'METRIC agent_report_link_policy_inconsistencies=%s\n' "$agent_report_link_policy_inconsistencies"
printf 'METRIC architecture_agent_static_target_inconsistencies=%s\n' "$architecture_agent_static_target_inconsistencies"
