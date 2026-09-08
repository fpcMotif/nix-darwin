# CLAUDE.md — Global Development Guidelines

## Identity

- **User**: f
- **Primary tools**: Claude Code (Opus), Droid (Factory), OpenCode, Zed
- **Package managers**: bun/bunx (never npm/npx), pnpm, uv (Python), cargo (Rust)
- **Terminal**: Ghostty + Kitty | Shell: Zsh | Prompt: Starship

## Tooling defaults

Rust CLIs replace the classic tools — use these in Bash:

| Classic | Use |
|---------|-----|
| `find` | `fd` |
| `grep` | `rg` |
| `cat` | `bat` |
| `ls` / `tree` | `eza` / `eza --tree` |
| `du` | `dust` |
| `ps` | `procs` |
| `top` | `btm` |
| `curl` (API calls) | `xh` |
| diff viewing | `delta` |
| ad-hoc benchmarks | `hyperfine` |

## Python

- Never bare `python`, `python3`, or `pip`: the system interpreter is 3.9. Everything runs through uv, which owns its interpreters (3.14 installed).
- Script or one-liner: `uv run script.py` with deps declared in `# /// script` metadata; `uv run --with httpx python -c '...'`.
- Project: `uv sync`, `uv add pkg`, `uv run pytest`. No venv activation, no pip, no requirements.txt.
- Lint and format: `ruff check --fix . && ruff format .` (ruff is on PATH; `uvx ruff@<ver>` only when the project pins one).
- Types: `uvx ty check`. ty is pre-1.0; if the repo already configures pyright or mypy, run that one via `uvx` instead.

## Code search routing

Measured 2026-09 on this machine; numbers and failure modes in ~/.claude/search-eval.md. The token savings came from answer shape (a definition with its callers in one call, spans instead of whole files, counts before listings), not engine speed. Inside one repo the built-in Grep and Glob tools are fine.

<repo> = absolute path of the git root you work in. Never search ~/devv itself (65k files, sibling checkouts of the same repo); a hook denies rg there without a sub-path.

Procedure. Stop as soon as you can act; three lookups usually suffice. Batch independent lookups in one Bash call with `;`.
1. Symbol name known -> `codedb <repo> explain SYM`: definition body plus every call site. Its enclosing-function labels are wrong inside loops and lambdas; for the enclosing function or the flags a caller tests -> `rw --callers=SYM`.
2. File known -> `codedb <repo> outline FILE`, then read only that span: Read with offset/limit, or `codedb <repo> read FILE -L A-B`. A hook denies a limit-less Read of a code file over 300 lines.
3. Only words known -> `rw --for="words plus any identifier you know"`: ranked signatures, rank 1 is the anchor. Then step 2 on that file.
4. Every mention of a text (barrels, docs, strings, comments, counts) -> `rg -c PAT <repo>` first, then `rg -n -w PAT <repo>`. One identifier per query; `-C2` for context, `-U` for multiline. Above ~20k files use `tg` (same flags, indexed) instead of rg.
   An absence claim needs an exhaustive scan: `rg -uu -c PAT <repo>` or `tg -c PAT <repo>`. Never codedb, fff, or zg for absence. Name the tool and scope behind every "not found".
5. Before saying done: `rw --edit-check=SYM` (callers broken by a new arity); `rw --test-gate` (exit 4 names tests to run; it does not run them, so run them); `rw --quality-delta` (exit 2 = a pre-existing symbol got materially worse).

Wrappers on PATH: `tg` = tgrep with a per-repo index in ~/.cache, same flags as rg. `rw` = ripwire with node_modules excluded and legends stripped; `rw --verb=...` inside <repo>, or `rw <repo> --verb=...`.

MCP or CLI. codedb, fff, and zg each run as an MCP server: same answers as the CLI, typed parameters, no shell quoting. Their schemas are deferred, so the first MCP call in a session costs one ToolSearch round trip, and codedb's server needs ~12 s after start while its CLI is instant. Rule: CLI for the first lookups and inside subagents, MCP once the session is warm. Always pass project=<repo> (codedb) or root=<repo> (zg).
- codedb_explain for a symbol; codedb_context for a task, only with semantic=local (the default sends snippets to a remote reranker). Outline and read are CLI only.
- fff find_files for fuzzy filenames, recent and git-dirty first. Not fff grep to enumerate: it caps at 50 hits, and "0 exact matches" means absent.
- zg zvec_grep_search for word-only orientation on one TypeScript repo, with `fts: SYM` when you know a name. It returns vector neighbours even when nothing matched lexically, so a zg hit never proves presence.

Traps: `rw --uses=CONST` returns 0 for TypeScript constants (use `rg -w`); `rw --callers` misses calls inside anonymous callbacks such as test `it()` blocks; codedb skips node_modules and files over 2 MiB, rg and tg cover them; `codedb word` is uncapped (27k lines for `Config`) and a hook denies it without a pipe to head; the shell `grep` binary as a command is denied by a hook (`| grep` as a filter is fine); never `rg -r` (it means --replace).

Structural patterns (refactors, API usage) -> ast-grep: `sg -p 'console.log($$$)' --lang ts`, `sg --rewrite 'logger.debug($$$)' -p 'console.log($$$)'`.
A client-side limit is often mirrored by a differently named server constant joined only by a comment: after locating one, `rg -w` the identifier its comment names.

## Git

- Review changes before any commit; conventional format `type(scope): message`
- Jujutsu repos: the `/jj` skill covers the jj workflow and hunk-level review

## Code Quality

- Simplest direct way. No abstraction, option, or indirection until a second real use demands it.
- Comments only for what code can't say; no defensive checks
- Match existing codebase patterns; confirm a library is installed before using it
- Never expose secrets, keys, or tokens in code or logs
- bun/bunx for all package management and script execution (never npm/npx)

## Issues, specs, and any document a human reviews

Every issue, spec, PRD, or analysis you write or update has two readers: the agent that implements it and a human who must make sense of it in two minutes. Serve the human **first in the body**, above the agent-facing spec, in an "At a glance" section:

1. **Ask one clarifying question** before writing when the request leaves a real choice open (which fix, which scope, which reader). One question, then write.
2. **TL;DR** in three sentences: what is wrong, why, what changes.
3. **General case before this instance.** Describe the mechanism in general terms first so a reviewer can recognise the next occurrence, then the concrete case that exposed it.
4. **Evidence with real data.** Exact log lines, row values, server timestamps to the millisecond where event order is the point. Label estimates as estimates. Put failing cases beside working ones in a comparison table across the variables that might explain it, so what does *not* correlate is visible.
5. **More than one kind of visual.** Mermaid (renders in GitHub, Linear, most wikis) is the default for sequence, state, and flow. Pair it with at least one other form the mechanism calls for: a monospace timeline, an annotated code path, a before/after table, a can/cannot matrix. One idea per visual, with a caption.
6. **A picture version** via `/eli5` or a published artifact when the mechanism is subtle or the reviewer is not the implementer. Link it at the foot: `[eli5 artifact: <name>](<url>)`.

**Done when** a reviewer who reads only "At a glance" can state the root cause, name the fix, and say what stays unchanged.

**On update**, a comment that changes the analysis (a correction, a measured number replacing an estimate, a new decision) carries its own evidence and visual, and the body is edited so it no longer contradicts the comment.

## Writing Style

Be concise. Sacrifice grammar for concision. Short sentences, plain words, define or cut jargon. McCloskey/Pinker standard, not academic hedging. Never touch facts, quotes, citations, or code for style — only the words around them.
