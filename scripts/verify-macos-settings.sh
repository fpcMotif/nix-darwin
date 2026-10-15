#!/usr/bin/env bash
# The hermetic tests/integration/darwin-settings-test.nix cannot see whether activation
# applied the settings (docs/adr/0004-macos-settings-testing-strategy.md).
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

expect() {
  local label="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then
    ok "$label (= $got)"
  else
    bad "$label: want [$want] got [$got]"
  fi
}

read_default() { defaults read "$1" "$2" 2>/dev/null || echo "<unset>"; }
read_global_default() { defaults read -g "$1" 2>/dev/null || echo "<unset>"; }

expect_command_output_contains() {
  local label="$1" needle="$2"
  shift 2
  local command=("$@") out
  if ! out="$("${command[@]}" 2>/dev/null)"; then
    na "$label (could not read: ${command[*]}; may need sudo)"
    return
  fi
  if printf '%s' "$out" | grep -qF -- "$needle"; then
    ok "$label"
  else
    bad "$label: expected output to contain [$needle]"
  fi
}

# launchd prints a disabled label as either `=> true` or `=> disabled`, and the
# activation engine treats both as disabled.
check_launchd_disabled() {
  local label="$1" disabled_list="$2" domain="$3"
  if [ -z "$disabled_list" ]; then
    na "$label ($domain unreadable; may need sudo)"
  elif printf '%s' "$disabled_list" | grep -Eq "\"$label\" => (true|disabled)"; then
    ok "$label is disabled"
  elif printf '%s' "$disabled_list" | grep -qF "$label"; then
    na "$label present but not in disabled state"
  else
    na "$label not currently registered ($domain)"
  fi
}

# Tier 1 already locks in the full key set. Ambiguous-domain keys (trackpad,
# menuExtraClock, ActivityMonitor) have no reliable read-back domain.
# `defaults` stores booleans as 1/0.
section "system.defaults (sampled live read-back)"
expect "NSGlobalDomain.KeyRepeat" 1 "$(read_global_default KeyRepeat)"
expect "NSGlobalDomain.InitialKeyRepeat" 10 "$(read_global_default InitialKeyRepeat)"
expect "NSGlobalDomain.ApplePressAndHoldEnabled" 0 "$(read_global_default ApplePressAndHoldEnabled)"
expect "NSGlobalDomain.AppleKeyboardUIMode" 3 "$(read_global_default AppleKeyboardUIMode)"
expect "NSGlobalDomain._HIHideMenuBar" 1 "$(read_global_default _HIHideMenuBar)"
expect "dock.autohide" 1 "$(read_default com.apple.dock autohide)"
expect "dock.orientation" left "$(read_default com.apple.dock orientation)"
expect "dock.tilesize" 48 "$(read_default com.apple.dock tilesize)"
expect "dock.show-recents" 0 "$(read_default com.apple.dock show-recents)"
expect "dock.mru-spaces" 0 "$(read_default com.apple.dock mru-spaces)"
expect "finder.NewWindowTarget" PfHm "$(read_default com.apple.finder NewWindowTarget)"
expect "finder.FXPreferredViewStyle" clmv "$(read_default com.apple.finder FXPreferredViewStyle)"
expect "finder.ShowPathbar" 1 "$(read_default com.apple.finder ShowPathbar)"
expect "finder.AppleShowAllExtensions" 0 "$(read_default com.apple.finder AppleShowAllExtensions)"
expect "finder.AppleShowAllFiles" 1 "$(read_default com.apple.finder AppleShowAllFiles)"
expect "screencapture.location" "~/Pictures" "$(read_default com.apple.screencapture location)"
expect "screencapture.type" png "$(read_default com.apple.screencapture type)"
expect "screencapture.name" screenshot "$(read_default com.apple.screencapture name)"

# Tier 1 can only string-match the imperative layer in activation text, so the
# read-backs from here on are the only proof that layer applied.
section "Power management (pmset)"
if pmset_settings="$(pmset -g custom 2>/dev/null)"; then
  # Apple Silicon hides hibernatemode and standbydelay*, yet activation emits
  # them (Tier 1 asserts that). An absent key is a no-op, not drift.
  for key_and_value in "displaysleep 15" "disksleep 30" "womp 0" "powernap 0" \
    "tcpkeepalive 0" "standby 1" \
    "hibernatemode 3" "standbydelayhigh 7200" "standbydelaylow 3600"; do
    key="${key_and_value%% *}"
    expected_value="${key_and_value##* }"
    line="$(printf '%s' "$pmset_settings" | grep -E "^[[:space:]]*${key}[[:space:]]+" | head -1)"
    if [ -z "$line" ]; then
      na "pmset ${key} not exposed on this hardware (Apple Silicon)"
    else
      expect "pmset ${key}" "$expected_value" "$(printf '%s' "$line" | awk '{print $2}')"
    fi
  done
else
  na "pmset -g custom unreadable"
fi

section "Gatekeeper / quarantine"
expect_command_output_contains "spctl assessments enabled" "enabled" /usr/sbin/spctl --status
expect "LSQuarantine on (downloads tagged)" 1 "$(read_default com.apple.LaunchServices LSQuarantine)"

section "Application firewall"
expect_command_output_contains "firewall globalstate enabled" "enabled" \
  /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
expect_command_output_contains "firewall stealth mode on" "stealth mode is on" \
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
if [ -d "$HOME/Library/Rime" ]; then
  ok "~/Library/Rime exists"
else
  na "~/Library/Rime not synced yet"
fi

section "GUI-managed apps"
# BetterMouse and BetterDisplay are deliberately not Nix-managed: both ship
# Sparkle and self-update out from under a pin. See docs/adr/0011-* and 0012-*.
for agent in bettermouse betterdisplay; do
  if launchctl list 2>/dev/null | grep -qi "$agent"; then
    bad "$agent LaunchAgent is loaded: these apps should be GUI-managed, not Nix-managed"
  else
    ok "$agent has no Nix LaunchAgent (GUI-managed, as intended)"
  fi
done

section "Background-churn suppression (CleanMyMac)"
# CleanMyMac's Agent is a system-domain label (baseline-activation.nix marks it
# kind=system) and never shows up in the gui domain.
gui_disabled="$(launchctl print-disabled "gui/$(id -u)" 2>/dev/null || true)"
sys_disabled="$(sudo -n launchctl print-disabled system 2>/dev/null || true)"
check_launchd_disabled com.macpaw.CleanMyMac5.HealthMonitor "$gui_disabled" "gui domain"
check_launchd_disabled com.macpaw.CleanMyMac5.Agent "$sys_disabled" "system domain"

section "Spotlight dev-tree exclusions"
for dev_tree in gosh-my-pi .codex; do
  if [ -e "$HOME/$dev_tree/.metadata_never_index" ]; then
    ok "$dev_tree has a .metadata_never_index marker"
  else
    na "$dev_tree not present or unmarked"
  fi
done

printf '\n\033[1mSummary:\033[0m %s  %s  %s\n' \
  "$(green "${pass} passed")" "$(red "${fail} failed")" "$(yellow "${skip} skipped")"
[ "$fail" -eq 0 ]
