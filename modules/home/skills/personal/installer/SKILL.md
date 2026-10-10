---
name: installer
description: Audit and execute remote shell installers safely via ax and bashka without curl. Triggers: install.sh, curl-to-shell URLs, bashka package management.
---

# Remote Installer Execution

Stream shell install scripts through `bashka` AST analysis and sandbox tracking, using `ax` as the fetcher.

## Workflow

### 1. Audit (Dry-Run)
Inspect AST findings and risk score without executing:

```bash
ax <URL> --body | bashka --check
```

Exit codes: `0` clean, `1` neutral, `2` red, `3` strong gate. Non-zero: inspect flagged AST lines before proceeding.

### 2. Install and Register
Execute and record created binaries in the install registry:

```bash
ax <URL> --body | bashka --name <pkg> [--yes]
```

- `--name <pkg>`: required for clean tracking in `~/.local/share/bashka/installed.toml`.
- `--yes`: auto-approves safe prompts up to the strong gate.

### 3. Verify
```bash
bashka info <pkg> && <pkg> --version
```

---

## Constraints

- **`ax --body` mandatory**: bare `ax` emits JSON metadata, triggering `bashka`'s `not_a_script` rejection.
- **Lifecycle**:
  - `bashka list`: view tracked packages.
  - `bashka remove <pkg>`: delete all recorded binaries and created directories.
