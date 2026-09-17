## Command routing

Use a purpose-built tool before its shell equivalent. Confirm it is exposed; use the documented fallback when absent.

| Job | Command |
| --- | --- |
| Read a file or span | `bat -pp FILE`, `bat -pp --line-range A:B FILE` |
| List a directory | `eza -la DIR`, `eza --tree -L 2 DIR` |
| Find files outside FFF's root | `fd PATTERN DIR` |
| Exhaustive text search | `rg -n PAT DIR` |
| Copy files | `fcp SOURCE DESTINATION` |
| Jump to a directory | `z NAME`, or `z NAME && COMMAND` in one call |
| Disk usage | `dust` |
| Processes | `procs` |
| CPU and memory | `btm` |
| HTTP | `ax URL` |
| View a diff | `delta` |
| Time a command | `hyperfine` |
| Structural search | `sg -p 'PATTERN' --lang LANGUAGE` |

Bound discovery output with `head -n 20`. Narrow a lookup that exceeds ten seconds.
Use `ax` for HTTP. Use `curl` only after `ax` lacks the capability or returns a concrete failure.

## Code search

The Search section of the host guide names the first tool for each case. These rules hold on every host. Stop when the evidence supports action.

1. **Scope**: Search inside one repository. The `~/devv` umbrella holds 65k files of sibling checkouts.
2. **Fallback**: Without the MCP servers, run `codedb <repo> file NAME`, `codedb <repo> explain SYM`, or `codedb <repo> context --local TASK`.
3. **Words**: When no name is known, use ranked search to find an anchor, then inspect its symbol or file.
4. **Exhaustive**: Use `rg` for every mention, count, or absence claim. Name the searched scope.

Ranked results alone cannot prove absence.

## JavaScript and TypeScript

- Run scripts with `bun` and executables with `bunx`.
- Use `pnpm` when the repository requires it.
- Confirm a dependency and lockfile before adding a library.

## Python

- Run every Python command through `uv`.
- Script: `uv run script.py`. Declare standalone dependencies in PEP 723 metadata.
- One-liner: `uv run --with PACKAGE python -c '...'`.
- Project: `uv sync`, `uv add PACKAGE`, `uv run pytest`.
- Save substantial Python as a `.py` file before execution.
- Check changed files with `ruff check --fix`, `ruff format`, and `uvx ty check`.
- Verify a small sample before the full workload.

## Version control

- Detect a `.jj` workspace before the first version-control operation.
- Use `jj` in a Jujutsu workspace and Git in a Git-only checkout.
- Read the diff before every commit. Use `type(scope): message`.
- Use `gh` for GitHub when no host-specific GitHub tool applies.
- Inspect diff shape first, then read path-scoped changes.
