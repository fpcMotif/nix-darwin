{ lib, ... }:

{
  programs.zsh.initContent = lib.mkAfter ''
    jot() {
      local msg="$*"
      local daily_path
      daily_path="$(notesmd-cli daily --print-path)" || return 1
      printf -- '- %s\n' "$msg" >> "$daily_path" && echo "Noted to $daily_path"
    }

    oc-vault() { opencode "$OBSIDIAN_VAULT"; }
    oc-study() { opencode "$OBSIDIAN_VAULT/Learning"; }
    oc-daily() {
      local daily_path
      daily_path="$(notesmd-cli daily --print-path)" || return 1
      opencode "$daily_path"
    }
    oc-note() {
      local note_path
      note_path="$(notesmd-cli create --print-path "$@")" || return 1
      opencode "$note_path"
    }

    _obd_domain="gui/$(id -u)"
    _obd_label="com.f.obsidian-headless.sync"
    _obd_svc="''${_obd_domain}/''${_obd_label}"
    _obd_plist="$HOME/Library/LaunchAgents/''${_obd_label}.plist"

    obd-load() {
      launchctl bootstrap "$_obd_domain" "$_obd_plist" 2>/dev/null || true
    }
    obd-start() {
      obd-load
      launchctl kickstart -k "$_obd_svc"
    }
    obd-stop() { launchctl bootout "$_obd_svc"; }
    obd-reload() {
      launchctl bootout "$_obd_svc" 2>/dev/null || true
      obd-load
      launchctl kickstart -k "$_obd_svc"
    }
    obd-status() { launchctl print "$_obd_svc"; }
    ob-log() { /usr/bin/tail -n 100 -f "$HOME/Library/Logs/obsidian-headless/sync.stdout.log"; }
    ob-err() { /usr/bin/tail -n 100 -f "$HOME/Library/Logs/obsidian-headless/sync.stderr.log"; }
    vault() { open "$OBSIDIAN_VAULT"; }
  '';
}
