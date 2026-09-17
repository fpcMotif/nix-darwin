---
name: remctl-macos-reminders
description: "Interact with, diagnose, and maintain remctl (Apple Reminders CLI on macOS) and its Swift/ReminderKit bridges"
---

# remctl-macos-reminders

Procedures for configuring, running, and diagnosing `remctl` (macOS Apple Reminders power-user CLI by Federico Viticci).

## Overview

`remctl` reads directly from the local iCloud Reminders SQLite database (`~/Library/Group Containers/group.com.apple.reminders/Container_v1/Stores/Data-*.sqlite`) for fast queries, writes via `remctl-bridge` (EventKit), and handles private metadata (sections, subtasks, tags, attachments, grocery categorisation, smart lists, templates) via `remctl-private` (ReminderKit).

Aliases installed: `remctl`, `rctl`, `reminders`.

## Requirements & Locations

- **CLI & Helpers**: `~/.local/bin/remctl`, `~/.local/bin/remctl-bridge`, `~/.local/bin/remctl-permissions`, `~/.local/bin/remctl-private`, and Python helper modules.
- **Python Version**: Requires Python 3.10+. Python 3.11 is symlinked in `~/.local/bin/python3`.
- **Config Directory**: `~/.config/remctl`
- **Shell Completions**: `~/.zsh/completions/_remctl`, `_rctl`, `_reminders` with `fpath` configured via `~/.config/zsh/function.zsh` and `~/nix-config/modules/home/zsh.nix`.

## Diagnostic Verification

Always run the built-in diagnostic tool to verify database and EventKit permissions:
```bash
remctl doctor
```
Expected output: 12 checks passed, 0 failures.

If permissions need setup/reset:
```bash
remctl permissions full-disk-access
```

## Common Operations

### Read Reminders & Lists
```bash
remctl today                    # Due today & overdue
remctl lists                    # List all lists & groups
remctl show <list>              # Show items in list
remctl show <list> --format table
remctl show <list> --json
remctl search "<query>"
```

### Mutate Reminders
```bash
remctl add "Task title" -l Work -d "tomorrow 10:00" -p high
remctl done <id>
remctl edit <id> -d clear
remctl delete <id> --force
```

### Private Metadata (`--private`)
```bash
remctl add "Task" -l Work --private --subtask '{"title":"Subtask 1"}'
remctl list-create "Groceries" --private --groceries --grocery-locale en_US
remctl smart-lists --json
remctl smart-list-create "Flagged Review" --private --flagged
```
