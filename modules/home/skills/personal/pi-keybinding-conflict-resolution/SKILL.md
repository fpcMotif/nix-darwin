---
name: pi-keybinding-conflict-resolution
description: Diagnose and resolve Pi coding agent extension shortcut conflicts and manage keybindings.json overrides
---

# Diagnosing and Fixing Pi Coding Agent Keybinding Conflicts

When the Pi coding agent reports `Extension shortcut conflict: '<key>' is built-in shortcut for <builtin.action> and <extension_path>`, resolve the conflict via user settings rather than editing `node_modules`.

## 1. Root Cause
Pi extensions register shortcuts via `pi.registerShortcut("<combo>", { ... })`. When a combo collides with a core TUI action, Pi prioritizes the extension and prints a warning banner on startup.

## 2. Rebinding Built-in Shortcuts
Built-in action keys can be overridden without modifying packages by creating or editing `~/.pi/agent/keybindings.json`:

```json
{
  "<builtin.action>": "<new-key-combo>"
}
```

Example for transcript search (`tui.altScreen.search`):
```json
{
  "tui.altScreen.search": "ctrl+shift+s"
}
```

## 3. Finding Available Key Combos
Scan all installed extensions to ensure the new shortcut is unclaimed:
```bash
rg -n "registerShortcut\(" ~/.pi/agent/npm/node_modules ~/.pi/agent/git ~/.pi/agent/extensions 2>/dev/null
```
Cross-reference candidates against core keybindings in Pi's documentation (`docs/keybindings.md`).

## 4. Managing Providers and Credentials
- To cleanly remove unused extension packages: `pi remove <package-name>`
- When editing `~/.pi/agent/auth.json`, always ensure file permissions remain secure:
```bash
chmod 600 ~/.pi/agent/auth.json
```

## 5. Verification
1. Validate JSON syntax: `jq . ~/.pi/agent/keybindings.json`
2. Test clean startup without warning banners:
```bash
pi --no-session -na -nc
```
3. Run existing extension test suites:
```bash
cd ~/.pi/agent && bun test
```
