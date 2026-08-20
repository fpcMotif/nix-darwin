#!/usr/bin/env bash
set -euo pipefail

lib=$1
auto_switch=$2

. "$lib"

plain=$(NO_COLOR=1 au_report_change tool 1.33.55 1.33.80)
[ "$plain" = "tool  1.33.55 --> 1.33.80" ]

unset NO_COLOR
colored=$(FORCE_COLOR=1 au_report_change tool 1.33.55 1.33.80)
case "$colored" in
  *$'\033['*"tool"*$'\033['*"1.33.55"*"-->"*$'\033['*"1.33.80"*) ;;
  *) echo "colored update report missing ANSI fields: $colored" >&2; exit 1 ;;
esac

grep -qF 'archive --format=tar' "$auto_switch"
grep -qF 'snapshot=$(mktemp -d' "$auto_switch"
if grep -qF 'git+file://' "$auto_switch"; then
  echo "auto-switch must not ask root Nix to open the user-owned Git repo" >&2
  exit 1
fi
