# Hotkey Inventory And Design

This file is the current shortcut map for the Mac setup. The goal is to keep
global automation small, memorable, and conflict-resistant.

## Best Design

- Global automation: `skhd`, managed by nix-darwin in `modules/darwin/skhd.nix`.
- Global prefix: `ctrl + alt + shift`.
- App-local shortcuts: keep them inside each app config.
- Terminal-first split control: prefer Ghostty/tmux panes for coding layouts;
  use Raycast or richer automation only when the target is not terminal-native.
- Rich macOS automation: `Hammerspoon`, configured at `~/.hammerspoon/init.lua`.
- Input method shortcuts: leave `ctrl+space` and `ctrl+alt+space` alone.
- Optional future upgrade: if a single-key launcher prefix is wanted, add
  Karabiner later and map Caps Lock to `ctrl+alt+shift`.

## Global Hotkeys

Source: `modules/darwin/skhd.nix`

| Hotkey | Action |
| --- | --- |
| `ctrl+alt+shift+return` | Open Ghostty |
| `ctrl+alt+shift+space` | Open Raycast |
| `ctrl+alt+shift+a` | Open Claude |
| `ctrl+alt+shift+c` | Open Cursor |
| `ctrl+alt+shift+d` | Open Drafts |
| `ctrl+alt+shift+f` | Open Finder |
| `ctrl+alt+shift+g` | Open Gemini |
| `ctrl+alt+shift+s` | Open Safari |
| `ctrl+alt+shift+t` | Open Terminal |
| `ctrl+alt+shift+w` | Open Warp |
| `ctrl+alt+shift+n` | Open this Nix config in Cursor |
| `ctrl+alt+shift+h` | Open this hotkey guide |
| `ctrl+alt+shift+l` | Sleep display / lock if password-on-wake is enabled |
| `ctrl+alt+shift+r` | Reload skhd |

Add host-specific global bindings in `hosts/darwin/default.nix` under
`martin.skhd.extraConfig`.

## Ghostty Global Split Hotkeys

Source: `hosts/darwin/default.nix` (`martin.skhd.extraConfig`)

These forward to Ghostty's app-local keybinds when Ghostty is focused. In any
other app they only focus Ghostty, so the hotkey plane does not become a
macOS-wide tiling/window-manager policy.

| Hotkey | Action |
| --- | --- |
| `ctrl+alt+shift+e` | Ghostty split right |
| `ctrl+alt+shift+x` | Ghostty split down |
| `ctrl+alt+shift+z` | Toggle Ghostty split zoom |
| `ctrl+alt+shift+0` | Equalize Ghostty splits |
| `ctrl+alt+shift+left/right/up/down` | Move between Ghostty splits |

Terminal equivalents from the shell: `gsp right`, `gsp down`, `gsp zoom`,
`gsp equal`, and `gpn left/right/up/down`.

## Finder Cut And Move

Source: `modules/darwin/skhd.nix`

| Hotkey | Action |
| --- | --- |
| `cmd+x` in Finder | Mark selected files/folders as cut by using Finder copy, then enter cut mode |
| `cmd+v` in Finder after `cmd+x` | Trigger Finder's native move, equivalent to `cmd+option+v`, then exit cut mode |
| `cmd+c` after `cmd+x` | Cancel cut mode and copy normally |
| `escape` after `cmd+x` | Cancel cut mode |

Why this design: Finder already implements file moves as `cmd+c` followed by
`cmd+option+v`. The hotkey layer only changes the keyboard habit; the file move
itself remains native Finder behavior, including Finder progress UI, conflict
dialogs, cross-volume handling, metadata behavior, and integration with iCloud
or other File Provider locations.
This intentionally does not call `mv` or a custom Rust/Zig mover; Finder keeps
responsibility for same-volume renames, cross-volume copy/delete, conflict
prompts, progress UI, metadata, and iCloud/File Provider behavior.

## macOS Global Shortcuts

Source: `com.apple.symbolichotkeys`

| Hotkey | Meaning |
| --- | --- |
| `ctrl+space` | Select previous input source |
| `ctrl+alt+space` | Select next source in input menu |

Other enabled symbolic shortcut ids: `79`, `80`, `81`, `82`. These have no
custom key parameters in the plist, so the practical conflict risk is low.

## Raycast

Source: `~/Library/Preferences/com.raycast.macos.plist`

- Raycast is installed and monitoring global hotkeys.
- Plaintext preferences show onboarding shortcuts `cmd+,` and `Esc`.
- Raycast command hotkeys are stored in an encrypted database, so they are not
  directly extractable with `sqlite3`.

## Shortcuts App

The `shortcuts` command can list shortcuts, but it does not expose keyboard
shortcut assignments. No global Shortcut hotkeys were found in plaintext app
preferences during this audit.

## Hammerspoon

Source: `modules/darwin/hammerspoon.nix`

Hammerspoon is installed for richer automation than skhd should own: app/window
state, timers, watchers, menu bar items, event taps, and small macOS workflows.
The current config has no active global hotkeys, so it does not compete with
skhd. It sets up:

- auto-reload when `~/.hammerspoon/init.lua` changes;
- a short load notification;
- `martin.bind`, `martin.launchOrFocus`, and `martin.notify` helpers for future
  console experiments.

## Active Managed App Shortcuts

### Ghostty

Source: `modules/home/ghostty.nix`

| Hotkey | Action |
| --- | --- |
| `cmd+d` | Split right |
| `cmd+shift+d` | Split down |
| `cmd+shift+f` | Toggle split zoom |
| `cmd+shift+enter` | Toggle fullscreen |
| `cmd+alt+arrow` | Move between splits |
| `cmd+ctrl+arrow` | Resize splits |
| `cmd+shift+0` | Equalize splits |
| `cmd+shift+left/right` | Previous/next tab |

Terminal commands: `gsp right/down/zoom/equal` and `gpn left/right/up/down`.

### Tmux

Source: `modules/home/tmux.nix`

| Hotkey | Action |
| --- | --- |
| `ctrl+;` | Prefix |
| `prefix+backslash` | Split horizontally |
| `prefix+enter` | Split vertically |
| `prefix+c` | New window |
| `prefix+-`, `prefix+=`, `prefix+[`, `prefix+]` | Resize pane |
| `prefix+x` | Kill pane |
| `prefix+m` | Zoom pane |
| `prefix+r` | Reload tmux config |
| `prefix+v` | Copy mode |

### Zed

Source: `modules/home/zed.nix`

| Hotkey | Action |
| --- | --- |
| `cmd+shift+t` | New terminal |

### Rime / Squirrel

Source: `MyRime-main/default.yaml` and active `~/Library/Rime/default.yaml`

| Hotkey | Action |
| --- | --- |
| `ctrl+grave` | Open schema menu |
| `ctrl+shift+grave` | Open schema menu |
| `tab` / `shift+tab` while composing | Move candidate cursor |
| `alt+left/right` while composing | Move within composition |
| `ctrl+shift+3` | Toggle ASCII punctuation |
| `ctrl+shift+4` | Toggle traditionalization |

## Repo-Local Shortcut Files

These files contain additional shortcut maps, but several are source/legacy
dotfiles rather than active Home Manager outputs:

- `personal-settings-main/kitty/kitty.conf`
- `personal-settings-main/tmux/tmux.conf`
- `personal-settings-main/nvim/lua/keymap.lua`
- `personal-settings-main/nvim/lua/window.lua`
- `personal-settings-main/nvim/lua/terminal.lua`
- `personal-settings-main/nvim/lua/plugins/*.lua`
- `personal-settings-main/lazygit/config.yml`
- `personal-settings-main/mpv/input.conf`
- `personal-settings-main/yazi/keymap.toml`
