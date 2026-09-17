---
name: wecom-sheet-applescript-audit
description: "Automate step-by-step cell extraction, screenshot capture, and Markdown audit for WeCom (企业微信) spreadsheets via AppleScript on macOS"
---

# WeCom Spreadsheet Step-by-Step AppleScript Capture & Verification

## Overview
Automate step-by-step cell navigation, clipboard copying, and screenshot verification for WeCom (企业微信) online spreadsheets and desktop table views on macOS.

## Workflow

1. **Focus WeCom Window & Activate**
   Use AppleScript / System Events to bring the `企业微信` process and target document to front.

2. **Step-by-Step Grid Navigation & Clipboard Extraction**
   - Focus start cell (A1).
   - Loop `r` in rows, `c` in cols.
   - Keystroke `Command + C` to read exact clipboard text.
   - Run `screencapture -x -m` to archive step-by-step visual proof without shutter noise.
   - Advance column via `key code 48` (Tab) and advance row via `key code 36` (Return).

3. **Markdown Comparison & Audit**
   - Write captured logs to `~/Desktop/WeCom_Table_Verification/`.
   - Compare captured rows with Markdown tables (`table_*.md`) using Python verification script (`verify_table_data.py`).
