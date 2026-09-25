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
| Stop a command after N seconds | `timeout N COMMAND` |
| Structural search | `sg -p 'PATTERN' --lang LANGUAGE` |

Bound discovery output with `head -n 20`. Narrow a lookup that exceeds ten seconds.
Use `ax` for HTTP. Use `curl` only after `ax` lacks the capability or returns a concrete failure.

## Waiting and background work

Launch once, let the runner wait, inspect only for a reason, verify before reporting success.

- **Launch**: Start each job once. Run short commands and immediate dependencies in the foreground. Use managed background execution when independent work can continue; keep the task ID and output path.
- **Continue**: While a job runs, do independent work. When none remains and the runner resumes this session on completion, end the turn; dependent work stays pending. Finish required shell work before a foreground subagent or one-shot run ends.
- **Waiting calls**: `sleep`, repeated `ps`/`pgrep`/`top`, repeated status checks, and rereads of an unfinished log are turns spent on the clock; skip them. A second timer, watcher, or agent whose purpose is waiting is the same call in disguise. A running job is not a reason to restart it.
- **Inspect for a reason**: a user request, a specific failure or stall to diagnose, or a completion missing past its deadline. An unchanged check needs a new reason.
- **Condition, not clock**: For readiness or an external system without a completion event, wait on the condition, not the clock. Use one bounded operation with a deadline and explicit success and failure states.
- **Verify**: After completion, read the terminal status and the relevant output before claiming success. A launch, a partial log, or elapsed time is not a result.

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

## Rust

- Run Cargo through mbx (the mise tool `mr-boxington`): `mbx build`, `mbx test --workspace`, `mbx clippy --all-targets -- -D warnings`. mbx forwards each command to Cargo and shares compiled work across every checkout.
- Plain `cargo` also runs through mbx in zsh, whose PATH puts mbx's cargo shim first. `mbx COMMAND` works in any shell.
- For a slow build or a cache miss, run `mbx explain`. Check the setup with `mbx doctor`. Run `mbx gc --dry-run` before `mbx gc`.

## Project environments

- Agent shells never run direnv's prompt hook. In a project with `.envrc`, run commands through `direnv exec . COMMAND`.
- If direnv reports the `.envrc` is blocked, ask the user. `direnv allow` runs the file's code.

## mise

- mise is not activated in agent shells. In a project with `mise.toml`, run its tools with `mise exec -- COMMAND` and its tasks with `mise run TASK`.
- Run `mise install` once to fetch the versions the project pins.
- Pin a new tool in the project with `mise use TOOL@VERSION`. The global mise config belongs to the user.

## Environment variables

- A project with `.env.schema` uses Varlock. The schema is the typed source of truth for every variable.
- To add a variable, declare it in `.env.schema` with `@type`, and mark a secret `@sensitive`. Then regenerate types with `varlock codegen` (usually `bun run prepare`).
- Validate the environment with `varlock load`. Scan for leaked secrets with `varlock scan`.
- Read values through the generated types or the process environment. Leave `.env` files to Varlock.
- Keep `.env` loading off in mise (`_.dotenv = false` in `mise.toml`) and Bun (`env = false` in `bunfig.toml`), so Varlock checks every value.
- To add Varlock to a project, follow `~/.agents/skills/varlock-setup/SKILL.md`.

## Version control

- Detect a `.jj` workspace before the first version-control operation.
- Use `jj` in a Jujutsu workspace and Git in a Git-only checkout.
- Read the diff before every commit. Use `type(scope): message`.
- Use `gh` for GitHub when no host-specific GitHub tool applies.
- Inspect diff shape first, then read path-scoped changes.
