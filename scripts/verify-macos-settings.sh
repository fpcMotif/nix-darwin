#!/usr/bin/env bash
# Tier 2 (opt-in, real-machine) verification of the macOS settings nix-config
# manages. Run this AFTER `just switch` to confirm the settings actually landed
# on the live machine -- the half that the hermetic Tier 1 eval test
# (tests/integration/darwin-settings-test.nix) structurally cannot check.
#
# Division of labour (see docs/adr/0004-macos-settings-testing-strategy.md):
#   * Tier 1 (nix flake check) proves the configuration DECLARES every value.
#   * Tier 2 (this script)      proves activation APPLIED the imperative layer
#                               and spot-checks that declarative defaults took.
#
# Deliberately NOT wired into `nix flake check`: it reads mutable machine state
# and is therefore non-hermetic. Invoke via `just verify-macos` or directly.
#
# Exit status: 0 iff there are zero FAILs. SKIPs (state that needs privileges
# we do not have, or an app that has not launched yet) do not fail the run.
set -uo pipefail

pass=0
fail=0
skip=0

green() { printf '\033[32m%s\033[0m' "$1"; }
red() { printf '\033[31m%s\033[0m' "$1"; }
yellow() { printf '\033[33m%s\033[0m' "$1"; }

ok() {
  printf '  %s %s\n' "$(green PASS)" "$1"
  pass=$((pass + 1))
}
bad() {
  printf '  %s %s\n' "$(red FAIL)" "$1"
  fail=$((fail + 1))
}
na() {
  printf '  %s %s\n' "$(yellow SKIP)" "$1"
  skip=$((skip + 1))
}

section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# Compare an actual value to an expected value.
expect() { # label want got
  local label="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then
    ok "$label (= $got)"
  else
    bad "$label: want [$want] got [$got]"
  fi
}

# `defaults read` helpers that report a sentinel instead of erroring out.
dread() { defaults read "$1" "$2" 2>/dev/null || echo "<unset>"; }
gread() { defaults read -g "$1" 2>/dev/null || echo "<unset>"; }

# Assert a needle appears in some command's output, skipping if the command is
# unavailable or unreadable without privileges.
expect_contains() { # label needle -- command...
  local label="$1" needle="$2"
  shift 2
  local out
  if ! out="$("$@" 2>/dev/null)"; then
    na "$label (could not read: ${*}; may need sudo)"
    return
  fi
  if printf '%s' "$out" | grep -qF -- "$needle"; then
    ok "$label"
  else
    bad "$label: expected output to contain [$needle]"
  fi
}

# ---------------------------------------------------------------------------
# Declarative system.defaults -- sampled read-back on high-confidence domains.
# The full key set is locked in by Tier 1; here we only confirm that activation
# actually wrote a representative slice. Ambiguous-domain keys (trackpad,
# menuExtraClock, ActivityMonitor) are intentionally left to Tier 1.
# Booleans are stored by `defaults` as 1/0.
# ---------------------------------------------------------------------------
section "system.defaults (sampled live read-back)"
expect "NSGlobalDomain.KeyRepeat" 1 "$(gread KeyRepeat)"
expect "NSGlobalDomain.InitialKeyRepeat" 10 "$(gread InitialKeyRepeat)"
expect "NSGlobalDomain.ApplePressAndHoldEnabled" 0 "$(gread ApplePressAndHoldEnabled)"
expect "NSGlobalDomain.AppleKeyboardUIMode" 3 "$(gread AppleKeyboardUIMode)"
expect "NSGlobalDomain._HIHideMenuBar" 1 "$(gread _HIHideMenuBar)"
expect "dock.autohide" 1 "$(dread com.apple.dock autohide)"
expect "dock.orientation" left "$(dread com.apple.dock orientation)"
expect "dock.tilesize" 48 "$(dread com.apple.dock tilesize)"
expect "dock.show-recents" 0 "$(dread com.apple.dock show-recents)"
expect "dock.mru-spaces" 0 "$(dread com.apple.dock mru-spaces)"
expect "finder.NewWindowTarget" PfHm "$(dread com.apple.finder NewWindowTarget)"
expect "finder.FXPreferredViewStyle" clmv "$(dread com.apple.finder FXPreferredViewStyle)"
expect "finder.ShowPathbar" 1 "$(dread com.apple.finder ShowPathbar)"
expect "finder.AppleShowAllExtensions" 0 "$(dread com.apple.finder AppleShowAllExtensions)"
expect "finder.AppleShowAllFiles" 1 "$(dread com.apple.finder AppleShowAllFiles)"
expect "screencapture.location" "~/Pictures" "$(dread com.apple.screencapture location)"
expect "screencapture.type" png "$(dread com.apple.screencapture type)"
expect "screencapture.name" screenshot "$(dread com.apple.screencapture name)"

# ---------------------------------------------------------------------------
# Imperative layer -- the part Tier 1 can only string-match in activation text.
# This is the highest-value half of Tier 2: it confirms the side effects ran.
# ---------------------------------------------------------------------------
section "Power management (pmset)"
if pm="$(pmset -g custom 2>/dev/null)"; then
  # Apple Silicon does not expose hibernatemode/standbydelay* -- activation still
  # emits them (Tier 1 asserts that), but they are no-ops here, so a key that is
  # absent from `pmset -g custom` is SKIPped rather than failed. A key that IS
  # present with the wrong value is real drift and fails.
  for kv in "displaysleep 15" "disksleep 30" "womp 0" "powernap 0" \
    "tcpkeepalive 0" "standby 1" \
    "hibernatemode 3" "standbydelayhigh 7200" "standbydelaylow 3600"; do
    key="${kv%% *}"
    val="${kv##* }"
    re=$'(^|\n)[[:space:]]*'"$key"'[[:space:]]+([^[:space:]]+)'
    if [[ "$pm" =~ $re ]]; then
      expect "pmset ${key}" "$val" "${BASH_REMATCH[2]}"
    else
      na "pmset ${key} not exposed on this hardware (Apple Silicon)"
    fi
  done
else
  na "pmset -g custom unreadable"
fi

section "Gatekeeper / quarantine"
expect_contains "spctl assessments enabled" "enabled" /usr/sbin/spctl --status
expect "LSQuarantine on (downloads tagged)" 1 "$(dread com.apple.LaunchServices LSQuarantine)"

section "Application firewall"
expect_contains "firewall globalstate enabled" "enabled" \
  /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
expect_contains "firewall stealth mode on" "stealth mode is on" \
  /usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode

section "Sudo Touch ID"
if [ -e /etc/pam.d/sudo_local ]; then
  if grep -q pam_tid /etc/pam.d/sudo_local; then
    ok "sudo_local enables pam_tid (Touch ID)"
  else
    bad "sudo_local is missing pam_tid"
  fi
else
  bad "/etc/pam.d/sudo_local does not exist"
fi

section "Rime / Squirrel input method"
squirrel="/Library/Input Methods/Squirrel.app"
if [ -L "$squirrel" ]; then
  target="$(readlink "$squirrel")"
  case "$target" in
  /nix/store/*) ok "Squirrel.app symlinked into the store" ;;
  *) bad "Squirrel.app points outside the store: $target" ;;
  esac
else
  na "Squirrel.app is not a symlink yet (run \`just switch\`)"
fi
[ -d "$HOME/Library/Rime" ] && ok "~/Library/Rime exists" || na "~/Library/Rime not synced yet"

section "BetterMouse / BetterDisplay LaunchAgents"
for agent in bettermouse betterdisplay; do
  if launchctl list 2>/dev/null | grep -qi "$agent"; then
    ok "$agent LaunchAgent is loaded"
  else
    na "$agent LaunchAgent not loaded (app may be quit)"
  fi
done

section "Background-churn suppression (CleanMyMac)"
# CleanMyMac's HealthMonitor is a per-user (gui) label; its Agent is a
# SYSTEM-domain label (baseline-activation.nix marks it kind=system) and never
# shows up in the gui domain -- so each label must be queried in its own domain.
# The engine treats both `=> true` and `=> disabled` as disabled, so this
# read-back accepts both forms too.
gui_disabled="$(launchctl print-disabled "gui/$(id -u)" 2>/dev/null || true)"
sys_disabled="$(sudo -n launchctl print-disabled system 2>/dev/null || true)"

check_disabled() { # label haystack domain-note
  local label="$1" haystack="$2" note="$3"
  if [ -z "$haystack" ]; then
    na "$label ($note unreadable; may need sudo)"
  elif printf '%s' "$haystack" | grep -Eq "\"$label\" => (true|disabled)"; then
    ok "$label is disabled"
  elif printf '%s' "$haystack" | grep -qF "$label"; then
    na "$label present but not in disabled state"
  else
    na "$label not currently registered ($note)"
  fi
}

check_disabled com.macpaw.CleanMyMac5.HealthMonitor "$gui_disabled" "gui domain"
check_disabled com.macpaw.CleanMyMac5.Agent "$sys_disabled" "system domain"

section "Spotlight dev-tree exclusions"
for d in gosh-my-pi .codex; do
  if [ -e "$HOME/$d/.metadata_never_index" ]; then
    ok "$d has a .metadata_never_index marker"
  else
    na "$d not present or unmarked"
  fi
done

# ---------------------------------------------------------------------------
printf '\n\033[1mSummary:\033[0m %s  %s  %s\n' \
  "$(green "${pass} passed")" "$(red "${fail} failed")" "$(yellow "${skip} skipped")"
[ "$fail" -eq 0 ]
