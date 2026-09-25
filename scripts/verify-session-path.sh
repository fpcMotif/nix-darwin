#!/usr/bin/env bash
# Tier 2 (opt-in, real machine): prove the interactive shell (zsh or fish,
# per martin.shell.interactive) builds a duplicate-free PATH in all four
# modes (-c, -lc, -ic, -lic), both fresh and forked from a login session,
# and that the intended executables win: mbx's cargo shim for cargo, and the
# Nix copy of every command that also sits in a user directory.
#
# Usage:
#   bash scripts/verify-session-path.sh                   # live dotfiles
#   bash scripts/verify-session-path.sh "$HOME_FILES_DIR" # a built config, before switching
#
#     HOME_FILES_DIR=$(nix build --no-link --print-out-paths \
#       .#darwinConfigurations.f.config.home-manager.users.martinfan.home-files)
#
# The shell under test is the one the target configures: fish when it has
# .config/fish/config.fish and no .zshrc, zsh otherwise. VSP_SHELL=zsh|fish
# overrides that; VSP_FISH names the fish binary (default: the system
# profile's, else the first on PATH).
#
# Before a switch that first enables fish, /etc/fish does not yet run
# nix-darwin's environment. VSP_SYSTEM_ENV=<built set-environment> runs it in
# each fresh process first, as /etc/fish/nixos-env-preinit.fish will:
#
#     VSP_SYSTEM_ENV=$(nix build --no-link --print-out-paths \
#       .#darwinConfigurations.f.config.system.build.setEnvironment)
#
# Not part of `nix flake check`: it spawns real shells and reads real $HOME
# state. The project dev-shell case has its own section and exit bit, because a
# project tool winning there is the dev shell doing its job
# (docs/adr/0008-reproducible-dev-envs-and-cross-platform-purity.md).
#
# Interactive modes run without a pty so their stderr stays separate; `script`
# would merge it into stdout and hide startup errors.
#
# Exit status: bit 0 = a base-session or mbx check failed; bit 1 = the project
# dev-shell check failed. SKIP and WARN never fail the run.
set -euo pipefail

# The zshrc exports CDPATH with "." first, which makes `cd` print the
# directory and corrupt `$(cd ... && pwd)`.
unset CDPATH

# Associative arrays need bash >= 4; macOS /bin/bash is 3.2.
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  printf 'verify-session-path: needs bash >= 4 (associative arrays); found %s.\n' "${BASH_VERSION}" >&2
  printf 'verify-session-path: stock macOS /bin/bash is 3.2 -- invoke with the Nix-profile bash on PATH.\n' >&2
  exit 2
fi

pass=0
fail=0
skip=0
warned=0
BASE_FAIL=0
PROJECT_FAIL=0

green() { printf '\033[32m%s\033[0m' "$1"; }
red() { printf '\033[31m%s\033[0m' "$1"; }
yellow() { printf '\033[33m%s\033[0m' "$1"; }
blue() { printf '\033[34m%s\033[0m' "$1"; }
cyan() { printf '\033[36m%s\033[0m' "$1"; }

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
info() {
  printf '  %s %s\n' "$(blue INFO)" "$1"
}
# WARN: a real contradiction that must stay visible without failing the run,
# e.g. a command shadowed by an intentional shell function (the opencode and
# droid wrappers in modules/home/ai-cli.nix).
warn() {
  printf '  %s %s\n' "$(cyan WARN)" "$1"
  warned=$((warned + 1))
}
section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

need() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'verify-session-path: missing required tool: %s\n' "$1" >&2
    exit 2
  }
}
need awk

HOME_FILES_DIR="${1:-}"
if [ -n "$HOME_FILES_DIR" ] && [ ! -d "$HOME_FILES_DIR" ]; then
  printf 'verify-session-path: %s is not a directory\n' "$HOME_FILES_DIR" >&2
  exit 2
fi

. "$(dirname -- "${BASH_SOURCE[0]}")/lib/interactive-shell.sh"

SHELL_KIND=$(interactive_shell_kind "${HOME_FILES_DIR:-$HOME}" "${VSP_SHELL:-}")
case "$SHELL_KIND" in
  zsh)
    need zsh
    SHELL_BIN=/bin/zsh
    ;;
  fish)
    SHELL_BIN=$(fish_binary "${VSP_FISH:-}")
    [ -n "$SHELL_BIN" ] || need fish
    ;;
  *)
    printf 'verify-session-path: VSP_SHELL must be zsh or fish, got %s\n' "$SHELL_KIND" >&2
    exit 2
    ;;
esac

USER="${USER:-$(id -un)}"
MBX_SHIM="${HOME}/Library/Application Support/mbx/bin/cargo"
REQUIRED_NAMES=(cargo rustc bun opencode)
MODES=(-c -lc -ic -lic)

WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/verify-session-path.XXXXXX")
trap 'rm -rf "$WORKDIR"' EXIT

# Point the shell at the built config.
declare -a config_args=()
target_label="LIVE dotfiles"
if [ -n "$HOME_FILES_DIR" ]; then
  target_label="BUILT home-files ($HOME_FILES_DIR)"
  if [ "$SHELL_KIND" = zsh ]; then
    config_args=(ZDOTDIR="$HOME_FILES_DIR")
  else
    link_fish_config "$HOME_FILES_DIR" "$WORKDIR/xdg-config"
    config_args=(XDG_CONFIG_HOME="$WORKDIR/xdg-config")
  fi
fi

declare -a system_env_launch=()
if [ -n "${VSP_SYSTEM_ENV:-}" ]; then
  # shellcheck disable=SC2016 # expanded by the inner sh
  system_env_launch=(/bin/sh -c '. "$0" && exec "$@"' "$VSP_SYSTEM_ENV")
  target_label="$target_label + system env $VSP_SYSTEM_ENV"
fi

printf 'verify-session-path: testing %s with %s (%s)\n' "$target_label" "$SHELL_KIND" "$SHELL_BIN"

# Nix-owned: under /etc/profiles/, /run/current-system/ or /nix/, or exactly
# ~/.nix-profile/bin. The probes below repeat this rule in zsh and fish.
is_nix_owned_dir() { # $1 = dir
  case "$1" in
    /etc/profiles/*|/run/current-system/*|/nix/*) return 0 ;;
  esac
  [ "$1" = "${HOME}/.nix-profile/bin" ]
}

# ---------------------------------------------------------------------------
# The probe is sourced inside the shell under test, so it reports that
# shell's own PATH and lookups. It writes tab-separated records to stdout.
# ---------------------------------------------------------------------------
PROBE="$WORKDIR/probe.zsh"
cat >"$PROBE" <<'ZSH_PROBE'
print -r -- "GUARD"$'\t'"__NIX_DARWIN_SET_ENVIRONMENT_DONE=${__NIX_DARWIN_SET_ENVIRONMENT_DONE-<unset>}"
print -r -- "GUARD"$'\t'"__HM_SESS_VARS_SOURCED=${__HM_SESS_VARS_SOURCED-<unset>}"
print -r -- "GUARD"$'\t'"__HM_ZSH_SESS_VARS_SOURCED=${__HM_ZSH_SESS_VARS_SOURCED-<unset>}"

for _pe in "${(s/:/)PATH}"; do
  print -r -- "PATHENTRY"$'\t'"${_pe}"
done

# Record which names are executable in NIX and OTHER dirs. The glob's "-"
# follows symlinks: every Nix-profile binary is a link into /nix/store, and
# without it each Nix dir enumerates as empty.
typeset -A _has_nix _has_other
for _d in "${path[@]}"; do
  case "$_d" in
    /etc/profiles/*|/run/current-system/*|/nix/*) _kind=NIX ;;
    *)
      if [ "$_d" = "$HOME/.nix-profile/bin" ]; then _kind=NIX; else _kind=OTHER; fi
      ;;
  esac
  [ -d "$_d" ] || continue
  typeset -a _exe; _exe=("$_d"/*(N-.x:t))
  for _name in "${_exe[@]}"; do
    if [ "$_kind" = NIX ]; then _has_nix[$_name]=1; else _has_other[$_name]=1; fi
  done
done

# Discovered overlaps: names executable in both a NIX dir and an OTHER dir.
typeset -a _overlap_names
for _name in "${(k)_has_nix[@]}"; do
  [ -n "${_has_other[$_name]-}" ] && _overlap_names+=("$_name")
done
print -r -- "OVERLAP_COUNT"$'\t'"${#_overlap_names[@]}"
for _name in "${_overlap_names[@]}"; do
  print -r -- "OVERLAPNAME"$'\t'"${_name}"
done

# whence -p resolves on PATH only; whence -w detects an alias, function or
# builtin shadowing the name. VSP_REQUIRED comes from the wrapper.
typeset -a _required_names
_required_names=(${=VSP_REQUIRED})
print -r -- "REQCOUNT"$'\t'"${#_required_names[@]}"
typeset -A _to_check
for _n in "${_overlap_names[@]}" "${_required_names[@]}"; do _to_check[$_n]=1; done

for _name in "${(k)_to_check[@]}"; do
  _p_out=$(whence -p -- "$_name" 2>/dev/null)
  _w_out=$(whence -w -- "$_name" 2>/dev/null)
  print -r -- "WHENCE"$'\t'"${_name}"$'\t'"${_p_out:-<not-found>}"$'\t'"${_w_out:-<not-found>}"
done
ZSH_PROBE

# The same records from fish. `command -s` resolves on PATH only, like
# whence -p; `type -t` reports a function or builtin shadowing the name,
# rendered in whence -w's "name: kind" form.
FISH_PROBE="$WORKDIR/probe.fish"
cat >"$FISH_PROBE" <<'FISH_PROBE'
for guard in __NIX_DARWIN_SET_ENVIRONMENT_DONE __HM_SESS_VARS_SOURCED
    set -q $guard; and printf 'GUARD\t%s=%s\n' $guard "$$guard"; or printf 'GUARD\t%s=<unset>\n' $guard
end

for p in $PATH
    printf 'PATHENTRY\t%s\n' $p
end

set -l nix_names
set -l other_names
for d in $PATH
    test -d $d; or continue
    set -l names (path filter -fx -- $d/* | path basename)
    switch $d
        case '/etc/profiles/*' '/run/current-system/*' '/nix/*' "$HOME/.nix-profile/bin"
            set -a nix_names $names
        case '*'
            set -a other_names $names
    end
end

set -l overlap (comm -12 (printf '%s\n' $nix_names | sort -u | psub) (printf '%s\n' $other_names | sort -u | psub))
printf 'OVERLAP_COUNT\t%s\n' (count $overlap)
for name in $overlap
    printf 'OVERLAPNAME\t%s\n' $name
end

set -l required (string split -n ' ' -- $VSP_REQUIRED)
printf 'REQCOUNT\t%s\n' (count $required)
for name in (printf '%s\n' $overlap $required | sort -u)
    set -l p (command -s -- $name; or echo '<not-found>')
    set -l kind (type -t -- $name 2>/dev/null; or echo none)
    test "$kind" = file; and set kind command
    printf 'WHENCE\t%s\t%s\t%s: %s\n' $name $p[1] $name $kind[1]
end
FISH_PROBE

if [ "$SHELL_KIND" = fish ]; then
  PROBE=$FISH_PROBE
  source_probe="source '$PROBE'"
else
  source_probe=". '$PROBE'"
fi

# Keep only tagged probe records, minus any trailing CR.
clean_probe_output() {
  awk '
    BEGIN { n = split("GUARD PATHENTRY REQCOUNT OVERLAP_COUNT OVERLAPNAME WHENCE", tags, " ") }
    {
      line = $0
      sub(/\r$/, "", line)
      for (i = 1; i <= n; i++) {
        pat = tags[i] "\t"
        idx = index(line, pat)
        if (idx == 1) { print line; next }
      }
    }
  ' "$1"
}

# Without a TTY, interactive zsh prints this line twice because zle cannot
# start. It is harmless, and the only stderr line ever filtered.
BENIGN_ZLE_LINE="(eval):1: can't change option: zle"
filter_benign_stderr() { # $1 = err file; prints only the UNEXPECTED lines
  awk -v benign="$BENIGN_ZLE_LINE" '
    { line = $0; sub(/\r$/, "", line) }
    line == benign { next }
    { print line }
  ' "$1"
}

# The first Nix-owned cargo on a probed shell's own PATH.
find_nix_cargo_from_probe() { # $1 = probe .out file; prints the path or nothing
  local d
  while IFS= read -r d; do
    if is_nix_owned_dir "$d" && [ -x "$d/cargo" ]; then
      printf '%s\n' "$d/cargo"
      return 0
    fi
  done < <(clean_probe_output "$1" | awk -F'\t' '$1 == "PATHENTRY" { print $2 }')
  return 1
}

# Run every assertion for one already-captured (out, err) pair and fold any
# failure into BASE_FAIL. $mode is one of -c/-lc/-ic/-lic; $session is
# "clean" or "inherited" and also gates the guard-inheritance assertion
# below (only meaningful for "inherited").
process_shell_output() {
  local mode="$1" session="$2" out="$3" err="$4"
  local had_fail=0 n_err _line name p w
  local guard_nix_darwin="" guard_hm_sess="" guard_hm_zsh=""
  section "${SHELL_KIND} ${mode}  (${session}, ${target_label})"

  local unexpected_err
  unexpected_err=$(filter_benign_stderr "$err")
  if [ -n "$unexpected_err" ]; then
    n_err=$(printf '%s\n' "$unexpected_err" | wc -l | tr -d ' ')
    bad "stderr not clean (${n_err} line(s)) -- printed verbatim:"
    while IFS= read -r _line; do
      printf '        %s\n' "$_line"
    done <<<"$unexpected_err"
    had_fail=1
  elif [ -s "$err" ]; then
    ok "stderr clean (only the documented no-TTY zle message, filtered)"
  else
    ok "stderr clean"
  fi

  local -a repeats=()
  local -A path_seen=()
  local path_count=0
  local -A whence_p=() whence_w=()
  local -a overlap_names=()
  local overlap_count="0" req_count=""

  while IFS=$'\t' read -r tag a b c; do
    case "$tag" in
      GUARD)
        case "$a" in
          __NIX_DARWIN_SET_ENVIRONMENT_DONE=*) guard_nix_darwin="${a#*=}" ;;
          __HM_SESS_VARS_SOURCED=*) guard_hm_sess="${a#*=}" ;;
          __HM_ZSH_SESS_VARS_SOURCED=*) guard_hm_zsh="${a#*=}" ;;
        esac
        ;;
      PATHENTRY)
        path_count=$((path_count + 1))
        if [ -n "${path_seen[$a]+x}" ]; then
          repeats+=("$a")
        fi
        path_seen[$a]=1
        ;;
      REQCOUNT) req_count="$a" ;;
      OVERLAP_COUNT) overlap_count="$a" ;;
      OVERLAPNAME) overlap_names+=("$a") ;;
      WHENCE)
        whence_p[$a]="$b"
        whence_w[$a]="$c"
        ;;
    esac
  done < <(clean_probe_output "$out")

  # Inherited children must carry the parent's exported guards; without them
  # section B would quietly retest the clean case.
  info "guard vars: __NIX_DARWIN_SET_ENVIRONMENT_DONE=${guard_nix_darwin:-<unset>} __HM_SESS_VARS_SOURCED=${guard_hm_sess:-<unset>} __HM_ZSH_SESS_VARS_SOURCED=${guard_hm_zsh:-<unset>}"
  if [ "$session" = "inherited" ]; then
    if [ "${guard_nix_darwin:-<unset>}" = "<unset>" ] || [ "${guard_hm_sess:-<unset>}" = "<unset>" ]; then
      bad "guard: inherited child did not inherit the parent's exported guard vars (__NIX_DARWIN_SET_ENVIRONMENT_DONE=${guard_nix_darwin:-<unset>} __HM_SESS_VARS_SOURCED=${guard_hm_sess:-<unset>})"
      had_fail=1
    else
      ok "guard: inherited child correctly inherited __NIX_DARWIN_SET_ENVIRONMENT_DONE=${guard_nix_darwin} __HM_SESS_VARS_SOURCED=${guard_hm_sess}"
    fi
  fi

  # 1. No PATH entry appears twice.
  if [ "$path_count" -gt 0 ] && [ "${#repeats[@]}" -eq 0 ]; then
    ok "PATH: ${path_count} entries, no duplicates"
  else
    bad "PATH: ${path_count} entries, ${#path_seen[@]} unique -- repeated: ${repeats[*]+"${repeats[*]}"}"
    had_fail=1
  fi

  # The probe must receive every required name. Otherwise a required name
  # that is also an overlap would still pass, and a lost handoff would hide.
  if [ "$req_count" != "${#REQUIRED_NAMES[@]}" ]; then
    bad "required: probe received ${req_count:-no} name(s), expected ${#REQUIRED_NAMES[@]} (VSP_REQUIRED not passed)"
    had_fail=1
  fi

  # 2. Required names resolve on PATH.
  for name in "${REQUIRED_NAMES[@]}"; do
    p="${whence_p[$name]:-<not-found>}"
    if [ "$name" = cargo ]; then
      if [ "$p" = "$MBX_SHIM" ]; then
        ok "required: cargo -> mbx shim ($p)"
      else
        bad "required: cargo -> '$p', expected mbx shim '$MBX_SHIM'"
        had_fail=1
      fi
    elif [ "$p" != "<not-found>" ] && is_nix_owned_dir "$(dirname -- "$p")"; then
      ok "required: $name -> $p (Nix-owned)"
    else
      bad "required: $name -> '$p', expected a Nix-owned directory"
      had_fail=1
    fi
  done

  # 3. Every name found in both a Nix-owned and another dir resolves to the
  # Nix copy (cargo: the mbx shim).
  if [ "$overlap_count" -eq 0 ]; then
    na "overlap: no overlaps tested"
  else
    local -a violations=()
    for name in ${overlap_names[@]+"${overlap_names[@]}"}; do
      p="${whence_p[$name]:-<not-found>}"
      if [ "$name" = cargo ]; then
        [ "$p" = "$MBX_SHIM" ] || violations+=("$name -> $p")
      elif [ "$p" = "<not-found>" ] || ! is_nix_owned_dir "$(dirname -- "$p")"; then
        violations+=("$name -> $p")
      fi
    done
    if [ "${#violations[@]}" -eq 0 ]; then
      ok "overlap: ${overlap_count} name(s) tested, all resolve into a Nix-owned dir (or the mbx shim for cargo)"
    else
      bad "overlap: ${overlap_count} name(s) tested, ${#violations[@]} violation(s): ${violations[*]}"
      had_fail=1
    fi
  fi

  # 4. Warn once per shadowed name. Intentional wrappers do not fail the run.
  if [ "${#whence_w[@]}" -gt 0 ]; then
    for name in "${!whence_w[@]}"; do
      w="${whence_w[$name]}"
      case "$w" in
        *": command") ;;
        "<not-found>"|*": none") ;;
        *) warn "$name resolves via whence -p to '${whence_p[$name]:-<not-found>}', but the bare command is shadowed by ${w#*: }" ;;
      esac
    done
  fi

  [ "$had_fail" -eq 1 ] && BASE_FAIL=1
  return 0
}

# ---------------------------------------------------------------------------
section "=== A. Clean: fresh env -i process, all four ${SHELL_KIND} modes ==="
# ---------------------------------------------------------------------------
for mode in "${MODES[@]}"; do
  out="$WORKDIR/clean${mode}.out"
  err="$WORKDIR/clean${mode}.err"
  env -i HOME="$HOME" USER="$USER" LOGNAME="$USER" TERM=xterm-256color \
    VSP_REQUIRED="${REQUIRED_NAMES[*]}" \
    ${config_args[@]+"${config_args[@]}"} ${system_env_launch[@]+"${system_env_launch[@]}"} \
    "$SHELL_BIN" "$mode" "$source_probe" \
    >"$out" 2>"$err" </dev/null || true
  process_shell_output "$mode" "clean" "$out" "$err"
done

# ---------------------------------------------------------------------------
section "=== B. Inherited: children forked from one clean login session ==="
# ---------------------------------------------------------------------------
# Children run without env -i, so they inherit the login parent's exports,
# including the Home Manager and nix-darwin guards. The parent file parses
# in both zsh and fish. zsh children resolve `zsh` on the parent's PATH.
child_bin=zsh
[ "$SHELL_KIND" = fish ] && child_bin=$SHELL_BIN
INH_PARENT="$WORKDIR/inh-parent.$SHELL_KIND"
cat >"$INH_PARENT" <<EOF
$child_bin -c   "$source_probe" >"$WORKDIR/inh-c.out"   2>"$WORKDIR/inh-c.err"   </dev/null
$child_bin -lc  "$source_probe" >"$WORKDIR/inh-lc.out"  2>"$WORKDIR/inh-lc.err"  </dev/null
$child_bin -ic  "$source_probe" >"$WORKDIR/inh-ic.out"  2>"$WORKDIR/inh-ic.err"  </dev/null
$child_bin -lic "$source_probe" >"$WORKDIR/inh-lic.out" 2>"$WORKDIR/inh-lic.err" </dev/null
EOF

parent_source=". '$INH_PARENT'"
[ "$SHELL_KIND" = fish ] && parent_source="source '$INH_PARENT'"
env -i HOME="$HOME" USER="$USER" LOGNAME="$USER" TERM=xterm-256color \
  VSP_REQUIRED="${REQUIRED_NAMES[*]}" \
  ${config_args[@]+"${config_args[@]}"} ${system_env_launch[@]+"${system_env_launch[@]}"} \
  "$SHELL_BIN" -lc "$parent_source" \
  >"$WORKDIR/inh-parent.out" 2>"$WORKDIR/inh-parent.err" </dev/null || true

if [ -s "$WORKDIR/inh-parent.err" ]; then
  section "${SHELL_KIND} -lc  (inherited parent, ${target_label})"
  bad "stderr not clean -- printed verbatim:"
  while IFS= read -r _line; do printf '        %s\n' "$_line"; done <"$WORKDIR/inh-parent.err"
  BASE_FAIL=1
fi

for mode in "${MODES[@]}"; do
  suffix="${mode#-}"
  process_shell_output "$mode" "inherited" "$WORKDIR/inh-${suffix}.out" "$WORKDIR/inh-${suffix}.err"
done

# ---------------------------------------------------------------------------
section "=== mbx cargo-shim smoke test (clean login shell) ==="
# ---------------------------------------------------------------------------
# Never runs ~/.cargo/bin/cargo: rustup's proxy can reach the network and
# install toolchains.
MBX_VER_OUT="$WORKDIR/mbx-shim-version.out"
MBX_VER_ERR="$WORKDIR/mbx-shim-version.err"
if [ -x "$MBX_SHIM" ]; then
  if "$MBX_SHIM" --version >"$MBX_VER_OUT" 2>"$MBX_VER_ERR"; then
    shim_ver=$(tr -d '\n' <"$MBX_VER_OUT")
    ok "mbx shim: '$MBX_SHIM --version' exits 0 ($shim_ver)"

    NIX_CARGO=""
    if [ -f "$WORKDIR/clean-lc.out" ]; then
      NIX_CARGO=$(find_nix_cargo_from_probe "$WORKDIR/clean-lc.out" || true)
    fi

    if [ -z "$NIX_CARGO" ]; then
      na "mbx delegate: unverified -- no Nix-owned cargo found on the clean -lc shell's own PATH"
    else
      nix_ver=$("$NIX_CARGO" --version 2>/dev/null || true)
      if [ -z "$nix_ver" ]; then
        na "mbx delegate: unverified -- $NIX_CARGO --version produced no output"
      elif [ "$nix_ver" = "$shim_ver" ]; then
        # Release banners are identical across rustup, Homebrew and Nix builds,
        # and mbx exposes no delegate path, so equal versions prove nothing.
        na "mbx delegate: unverified -- shim and Nix-owned cargo ($NIX_CARGO) report the identical version string ($shim_ver); version parity alone does not prove they are the same binary"
      else
        bad "mbx delegate: shim reports '$shim_ver' but the Nix-owned cargo at $NIX_CARGO reports '$nix_ver' -- not delegating to that Nix-owned cargo"
        BASE_FAIL=1
      fi
    fi
  else
    bad "mbx shim: '$MBX_SHIM --version' exited nonzero: $(tr -d '\n' <"$MBX_VER_ERR")"
    BASE_FAIL=1
  fi
else
  bad "mbx shim not found or not executable at '$MBX_SHIM'"
  BASE_FAIL=1
fi

# ---------------------------------------------------------------------------
section "=== Project dev-shell case (own section, own exit-code bit) ==="
# ---------------------------------------------------------------------------
# nix-config's devShell is expected to put its own tools ahead of the base
# profile -- that is the devShell doing its job, not a base-PATH failure, so
# it never sets BASE_FAIL, only PROJECT_FAIL.
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if command -v nix >/dev/null 2>&1; then
  DS_OUT="$WORKDIR/devshell.out"
  DS_ERR="$WORKDIR/devshell.err"
  DS_TIMEOUT="${VERIFY_SESSION_PATH_DEVSHELL_TIMEOUT:-90}"

  # Plain sh reads no startup files. A zsh probe reads /etc/zshenv, which
  # resets PATH unless the caller exported nix-darwin's guard. Bounded: a
  # first run may fetch, and a stalled fetch must fail this section rather
  # than hang the script.
  nix develop "$REPO_ROOT" -c sh -c 'command -v just' >"$DS_OUT" 2>"$DS_ERR" </dev/null &
  ds_pid=$!
  ds_waited=0
  while kill -0 "$ds_pid" 2>/dev/null && [ "$ds_waited" -lt "$DS_TIMEOUT" ]; do
    sleep 1
    ds_waited=$((ds_waited + 1))
  done

  if kill -0 "$ds_pid" 2>/dev/null; then
    kill -TERM "$ds_pid" 2>/dev/null || true
    sleep 1
    kill -KILL "$ds_pid" 2>/dev/null || true
    wait "$ds_pid" 2>/dev/null || true
    bad "devShell: 'nix develop' timed out after ${DS_TIMEOUT}s (offline or a slow/rate-limited fetch) -- own section, not a base-PATH failure"
    PROJECT_FAIL=1
  elif wait "$ds_pid"; then
    ds_path=$(tr -d '\n' <"$DS_OUT")
    case "$ds_path" in
      /nix/store/*)
        ok "devShell: just -> $ds_path (the project's /nix/store copy wins over the base profile)"
        ;;
      *)
        bad "devShell: just -> '$ds_path', expected a /nix/store/... path ahead of the base profile"
        PROJECT_FAIL=1
        ;;
    esac
  else
    bad "devShell: 'nix develop $REPO_ROOT -c sh -c command -v just' failed -- stderr printed verbatim:"
    while IFS= read -r _dsline; do printf '        %s\n' "$_dsline"; done <"$DS_ERR"
    PROJECT_FAIL=1
  fi
else
  na "devShell: nix not on PATH, cannot exercise the project dev shell"
fi

# ---------------------------------------------------------------------------
printf '\n%s: %d passed, %d failed, %d skipped, %d warned\n' "$(basename "$0")" "$pass" "$fail" "$skip" "$warned"

exit_code=0
[ "$BASE_FAIL" -eq 1 ] && exit_code=$((exit_code | 1))
[ "$PROJECT_FAIL" -eq 1 ] && exit_code=$((exit_code | 2))
exit "$exit_code"
