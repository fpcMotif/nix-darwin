---
name: wecom-sheet-jxa-audit
description: "Automate multi-tab WeCom (企业微信) spreadsheet silent background inspection, window capture via CoreGraphics Window ID, and cell-by-cell Markdown auditing on macOS using JXA"
---

# WeCom Multi-Tab JXA Silent Audit

Automates background inspection, offscreen GPU layer extraction, and character-exact cell auditing for multi-tab WeCom (企业微信) spreadsheets without stealing window focus.

## Fast Path

Execute the steps in order. Complete each criterion before advancing.

### 1. Discover Target Window ID
Query macOS `WindowServer` for the background WeCom spreadsheet window.
- **Action**: Run `CGWindowListCopyWindowInfo(0, 0)` in JXA to locate the window named `公司基础信息和发票模板` or matching width $> 1000\text{px}$.
- **Criterion**: Yields non-null `windowId` integer (e.g. `3794`) and target process `pid`.

### 2. Direct-to-PID Navigation
Send background navigation events directly to WeCom's Mach port via `$.CGEventPostToPid(pid, event)`.
- **Action**:
  - `Command + Up Arrow` (code `126`, flag `1048576`): Reset view to Row 1.
  - `Command + Left Arrow` (code `123`, flag `1048576`): Reset view to Column A.
  - `Page Down` (code `121`): Advance vertical pagination.
- **Criterion**: Target Mach queue receives events while `NSWorkspace.sharedWorkspace.frontmostApplication` remains unchanged.

### 3. Offscreen Layer Capture
Extract the GPU backing store for the confirmed Window ID.
- **Action**: Execute `screencapture -x -l<windowId> <outputPath>`.
- **Criterion**: Output PNG file exists on disk ($> 50\text{ KB}$) with valid header bytes.

### 4. Ground-Truth Data Audit
Run character-level assertions across the 3 local master Markdown files:
- **Action**: Execute `python3 verify_table_data.py`.
- **Criterion**: Reports `ALL_PASS` across:
  - `公司基础信息.md` (60/60 cells exact)
  - `发票银行信息-汇总.md` (8 entities, multi-currency accounts, SWIFT codes)
  - `国内开票资料.md` (42/42 cells exact)

## Reference: Dual-Engine Invocation

```bash
# Primary: JXA Silent Direct-to-PID Runner
# Fallback: AppleScript System Events Runner
osascript -l JavaScript wecom_silent_auditor.js || osascript wecom_sheet_verify.scpt
```
