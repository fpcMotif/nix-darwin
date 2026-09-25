#!/usr/bin/env bash
# Exercise the production settings reconciler with fixture policies and homes.
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: claude-settings-ownership-test.sh CURRENT OLD NEW RETIRED-SEED-NEW" >&2
  exit 2
fi
current=$1
old=$2
new=$3
retired_seed_new=$4
work=$(mktemp -d "${TMPDIR:-/tmp}/claude-settings-ownership.XXXXXX")
trap 'rm -rf -- "$work"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_json() {
  local filter=$1 file=$2 message=$3
  if ! jq -e "$filter" "$file" >/dev/null; then
    jq . "$file" >&2 || true
    fail "$message"
  fi
}

# A fresh dry run computes the seed reconciliation without creating HOME,
# settings.json, state, or even a temporary file.
dry_tmp="$work/fresh-dry-tmp"
mkdir -p "$dry_tmp"
dry_home="$work/fresh dry home"
[ ! -e "$dry_home" ] || fail "fresh dry-run home unexpectedly exists"
dry_log=$(TMPDIR="$dry_tmp" DRY_RUN=1 "$current" "$dry_home" 2>&1) \
  || fail "fresh dry run failed"
[ ! -e "$dry_home" ] || fail "fresh dry run created the home directory"
[ -z "$(find "$dry_tmp" -mindepth 1 -print -quit)" ] \
  || fail "fresh dry run created a temporary file"
case "$dry_log" in
  *"would change keys"*"permissions"*) ;;
  *) fail "fresh dry run did not report changed settings keys: $dry_log" ;;
esac

# A real first run seeds the file, then applies the policy in the same write.
fresh_home="$work/fresh-home"
"$current" "$fresh_home"
fresh_settings="$fresh_home/.claude/settings.json"
fresh_state="$fresh_home/.local/state/nix-config/claude-settings-ownership.json"
[ -f "$fresh_settings" ] || fail "first run did not create settings.json"
[ -f "$fresh_state" ] || fail "first run did not record owned keys"
assert_json '
  .model == "opus"
  and .permissions.allow == ["Bash(nix *)"]
  and .permissions.deny == ["Read(~/.ssh/**)"]
  and .permissions.defaultMode == "bypassPermissions"
  and .env.API_TIMEOUT_MS == "3000000"
  and .env.MISSING_DEFAULT == "filled-by-nix"
  and .enabledPlugins["parked@official"] == false
  and .autoMemoryEnabled == false
  and .autoDreamEnabled == false
  and .worktree.symlinkDirectories == ["node_modules", ".cache"]
  and any(.hooks.PreToolUse[]; any(.hooks[]; .command == "$HOME/.claude/hooks/shell-guard.sh"))
' "$fresh_settings" "fresh seed and owned policy were not reconciled"
assert_json '
  any(.owned[]; .path == ["permissions", "allow"] and .value == ["Bash(nix *)"])
  and ([.owned[] | select(.path[0] == "env" or .path[0] == "hooks")] | length) == 0
' "$fresh_state" "state did not record only current owned paths"

# User values win for defaults, owned permission keys revert, and siblings,
# manual hooks, plugins, and worktree settings remain intact.
home="$work/home with spaces"
mkdir -p "$home/.claude"
settings="$home/.claude/settings.json"
state="$home/.local/state/nix-config/claude-settings-ownership.json"
cat > "$settings" <<'JSON'
{
  "model": "user-model",
  "permissions": {
    "allow": ["Bash(user-added)", "Bash(nix *)"],
    "deny": ["Read(/tmp/**)"],
    "ask": ["Edit(/tmp/**)"],
    "defaultMode": "default",
    "additionalDirectories": ["/work", "/scratch"]
  },
  "env": {
    "API_TIMEOUT_MS": "user-timeout",
    "MISSING_DEFAULT": "",
    "NULL_DEFAULT": null,
    "FALSE_DEFAULT": false,
    "KEEP_ME": "user-value"
  },
  "skillOverrides": {
    "duplicate-skill": "on",
    "manual-skill": "on",
    "writing-great-skills": "on"
  },
  "enabledPlugins": {
    "parked@official": true,
    "kept@official": true,
    "user@market": false
  },
  "hooks": {
    "PreToolUse": [
      {"matcher":"Manual","hooks":[{"type":"command","command":"$HOME/.claude/hooks/manual.sh"}]}
    ],
    "PostToolUse": [
      {"matcher":"Wrong event","hooks":[{"type":"command","command":"$HOME/.claude/hooks/shell-guard.sh"}]},
      {"matcher":"Hand-added matcher","hooks":[{"type":"command","command":"$HOME/.claude/hooks/edit-batch-nudge.sh --user-argument"},{"type":"command","command":"$HOME/.claude/hooks/manual-post.sh"}]}
    ]
  },
  "autoMemoryEnabled": true,
  "autoDreamEnabled": true,
  "worktree": {"symlinkDirectories":["vendor"],"baseRef":"user-main"}
}
JSON
"$current" "$home"
assert_json '
  .model == "user-model"
  and .permissions.allow == ["Bash(nix *)"]
  and .permissions.deny == ["Read(~/.ssh/**)"]
  and .permissions.ask == ["Read(~/Downloads/**)"]
  and .permissions.defaultMode == "bypassPermissions"
  and .permissions.additionalDirectories == ["/work", "/scratch"]
  and .env.API_TIMEOUT_MS == "user-timeout"
  and .env.MISSING_DEFAULT == ""
  and (.env | has("NULL_DEFAULT")) and .env.NULL_DEFAULT == null
  and .env.FALSE_DEFAULT == false
  and .env.KEEP_ME == "user-value"
  and .skillOverrides["duplicate-skill"] == "off"
  and .skillOverrides["manual-skill"] == "on"
  and .skillOverrides["writing-great-skills"] == "on"
  and .enabledPlugins["parked@official"] == false
  and .enabledPlugins["kept@official"] == true
  and .enabledPlugins["user@market"] == false
  and .autoMemoryEnabled == false and .autoDreamEnabled == false
  and .worktree.symlinkDirectories == ["node_modules", ".cache"]
  and .worktree.baseRef == "user-main"
' "$settings" "owned/default values or preserved siblings are wrong"
assert_json '
  ([.hooks.PreToolUse[] | .hooks[] | select(.command == "$HOME/.claude/hooks/shell-guard.sh")] | length) == 1
  and any(.hooks.PreToolUse[]; .matcher == "Manual" and any(.hooks[]; .command == "$HOME/.claude/hooks/manual.sh"))
  and ([.hooks.PostToolUse[] | .hooks[] | select(.command == "$HOME/.claude/hooks/edit-batch-nudge.sh" or ((.command // "") | startswith("$HOME/.claude/hooks/edit-batch-nudge.sh ")))] | length) == 1
  and any(.hooks.PostToolUse[]; .matcher == "Hand-added matcher" and any(.hooks[]; .command == "$HOME/.claude/hooks/edit-batch-nudge.sh --user-argument"))
  and any(.hooks.PostToolUse[]; any(.hooks[]; .command == "$HOME/.claude/hooks/manual-post.sh"))
' "$settings" "hook add rule removed manual hooks, duplicated a guard, or matched the wrong event"
assert_json '
  any(.owned[]; .path == ["skillOverrides", "duplicate-skill"] and .value == "off")
' "$state" "ownership state does not contain the hidden skill value"

# A null env parent is empty for nested defaults, matching the old seed merge.
null_env_home="$work/null-env-home"
mkdir -p "$null_env_home/.claude"
printf '{"env":null}\n' > "$null_env_home/.claude/settings.json"
"$current" "$null_env_home"
assert_json '
  .env.API_TIMEOUT_MS == "3000000"
  and .env.MISSING_DEFAULT == "filled-by-nix"
' "$null_env_home/.claude/settings.json" "defaults were not filled beneath a null env parent"

# A semantically compliant but noncanonical file must stay byte-identical.
jq . "$settings" > "$work/noncanonical.json"
mv -- "$work/noncanonical.json" "$settings"
cp "$settings" "$work/settings.before-noop"
cp "$state" "$work/state.before-noop"
"$current" "$home"
cmp -s "$work/settings.before-noop" "$settings" \
  || fail "already-correct settings were rewritten"
cmp -s "$work/state.before-noop" "$state" \
  || fail "already-current ownership state was rewritten"

# A changed dry run reports the changed key and writes neither destination nor
# temporary files, even though a correction is needed.
jq '.permissions.allow = ["Bash(hand-edit)"]' "$settings" > "$work/drifted.json"
mv -- "$work/drifted.json" "$settings"
cp "$settings" "$work/settings.before-dry-run"
cp "$state" "$work/state.before-dry-run"
find "$home" -mindepth 1 -print | sort > "$work/home.before-dry-run"
dry_tmp="$work/existing-dry-tmp"
mkdir -p "$dry_tmp"
dry_log=$(TMPDIR="$dry_tmp" DRY_RUN=1 "$current" "$home" 2>&1) \
  || fail "existing-file dry run failed"
case "$dry_log" in
  *"permissions.allow"*) ;;
  *) fail "dry run did not name the changed permission key: $dry_log" ;;
esac
cmp -s "$work/settings.before-dry-run" "$settings" \
  || fail "dry run changed settings.json"
cmp -s "$work/state.before-dry-run" "$state" \
  || fail "dry run changed ownership state"
find "$home" -mindepth 1 -print | sort > "$work/home.after-dry-run"
cmp -s "$work/home.before-dry-run" "$work/home.after-dry-run" \
  || fail "existing dry run changed the home directory entries"
[ -z "$(find "$dry_tmp" -mindepth 1 -print -quit)" ] \
  || fail "existing-file dry run created a temporary file"

# Retire two formerly-owned keys. Remove only the unchanged one; a user's edit
# and unrelated sibling key must survive, and retired paths leave the ledger.
retired_home="$work/retired-home"
"$old" "$retired_home"
retired_settings="$retired_home/.claude/settings.json"
retired_state="$retired_home/.local/state/nix-config/claude-settings-ownership.json"
jq '
  .skillOverrides["retired-edited"] = "on"
  | .skillOverrides["manual-skill"] = "on"
' "$retired_settings" > "$work/retired-user-edit.json"
mv -- "$work/retired-user-edit.json" "$retired_settings"
"$new" "$retired_home"
assert_json '
  (.skillOverrides | has("retired-unchanged") | not)
  and .skillOverrides["retired-edited"] == "on"
  and .skillOverrides["manual-skill"] == "on"
' "$retired_settings" "stale cleanup did not preserve edited values and siblings"
assert_json '
  ([.owned[] | select(.path == ["skillOverrides", "retired-unchanged"] or .path == ["skillOverrides", "retired-edited"])] | length) == 0
' "$retired_state" "retired paths remain in the ownership state"

# If settings.json is missing, the seed is not a live value eligible for stale
# cleanup. Retiring autoMemoryEnabled must leave the seed value in the new file.
retired_seed_home="$work/retired-seed-home"
retired_seed_settings="$retired_seed_home/.claude/settings.json"
retired_seed_state="$retired_seed_home/.local/state/nix-config/claude-settings-ownership.json"
"$current" "$retired_seed_home"
rm -- "$retired_seed_settings"
"$retired_seed_new" "$retired_seed_home"
assert_json '
  .autoMemoryEnabled == false
  and .worktree.symlinkDirectories == ["node_modules", ".cache"]
' "$retired_seed_settings" "recreating settings retired a seed value without a live file"
assert_json '
  ([.owned[] | select(.path == ["autoMemoryEnabled"])] | length) == 0
' "$retired_seed_state" "retired seeded key remains in ownership state"

printf 'PASS unit-claude-settings-ownership\n'
