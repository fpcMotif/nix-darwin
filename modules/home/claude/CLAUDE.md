# CLAUDE.md — Global Development Guidelines

## Identity

- **User**: f
- **Package managers**: bun/bunx (JS), pnpm, uv (Python), cargo (Rust)

## Tooling defaults

In Bash, these are the commands, in bypass mode too.

| Job                          | Run                                             |
| ---------------------------- | ----------------------------------------------- |
| read a file, or a span of it | `bat -pp FILE`, `bat -pp --line-range A:B FILE` |
| list a directory             | `eza -la`, `eza --tree -L 2`                    |
| find files                   | `fd PATTERN`                                    |
| jump to a directory          | `z NAME`, `z /abs/path` (zoxide)                |
| disk usage                   | `dust`                                          |
| processes                    | `procs`                                         |
| live CPU and memory          | `btm`                                           |
| HTTP fetch, discovery, extraction, API calls | MUST use `ax URL` first; `curl URL` is allowed only as a documented fallback when ax lacks the required capability or fails for a concrete reason |
| view a diff                  | `delta`                                         |
| time a command               | `hyperfine`                                     |
| trim command output          | pipe into `head -n 20`                          |

Compose them: `fd -e ts | xargs sg -p 'PATTERN' --lang ts`, `rg -l PAT | xargs bat -pp --line-range 1:60`, `jj diff --git | delta`.

Timeouts: the default is 10 s and a lookup answers in under a second, so a lookup still running at 10 s is the wrong command; narrow it. Pass `timeout` for the slow classes: tests 120000, network calls 30000, nix builds and `just check` 600000; servers and watchers run in the background.

## Python

- Script or one-liner: `uv run script.py` with deps declared in `# /// script` metadata; `uv run --with httpx python -c '...'`.
- Project: `uv sync`, `uv add pkg`, `uv run pytest`.
- Lint and format: `ruff check --fix . && ruff format .`
- Types: `uvx ty check`; a repo that configures pyright or mypy gets that one via `uvx`.

## Code search routing

<repo> = the git root you work in; search ~/devv by sub-path (a hook denies its root). Stop as soon as you can act; batch independent lookups in one Bash call with `;`. Worked examples, wrappers, traps, and measurements: ~/.claude/search-routing.md.

1. Any identifier, even a guess -> codedb_explain (MCP; CLI `codedb <repo> explain SYM` in subagents): definition plus every call site, before opening a file.
2. File known -> `codedb <repo> outline FILE`, then read that span with Read offset/limit (a hook enforces it above 300 lines).
3. Only words -> `rw --for="words plus any identifier"`: rank 1 is the anchor; then step 2.
4. Fuzzy file name, two or three spellings, or an unindexed repo -> fff: `find_files`, `grep` with one bare identifier, `multi_grep`.
5. Every mention, counts, absence -> `rg -c PAT <repo>` then `rg -n -w PAT <repo>`; `tg` above ~20k files. An absence claim comes from `rg -uu -c` or `tg -c` and names the tool and scope.
6. Before done: `rw --edit-check=SYM`, `rw --test-gate` (run the tests it names), `rw --quality-delta`.

Structural patterns -> ast-grep: `sg -p 'console.log($$$)' --lang ts`.

## Git

- Review changes before any commit; conventional format `type(scope): message`
- jj first. A repo with `.jj/` takes jj commands; the `/jj` skill has the workflow, hunk curation, and the colocated contract for git-reading tools. A git-only repo whose change needs splitting: offer `jj git init --colocate`.
- Review is the code-review skill. Fixed point defaults to trunk (`main`). It reads committed history, so commit first (`jj new` in jj); the still-open change goes through ripwire-change-check. A PR: fixed point is its base, state and threads from better-github-skill.
- GitHub through the better-github-skill: PR state, review threads, and CI failures in one bounded call each; raw `gh` for the rest. Posting a review is `/code-review`, when the user asks.
- Diff shape before diff lines: `calldiff diff [from] [to]`, then a stat to pick files, then diffs of those paths.
- Human review of agent changes: `hunk diff --watch` in the user's terminal, then `hunk skill path` and load that skill. A walkthrough: a change doc piped to `bunx glimpse-changes -`.

## Code Quality

- Simplest direct way. Add an abstraction, option, or indirection when a second real use demands it.
- Edit the lines that change; rewrite a whole file when most of it changes.
- Keep a test that fails when every function it imports returns `undefined`; assert a literal output or an observable effect.
- When two fixes that share an assumption fail the same check, write the assumption down and test it before a third fix.
- Code explains itself: names and structure carry the what and the how. A comment or JSDoc carries only the why the code cannot show, in one or two lines. Clear code stands alone. Trust callers: checks live at the edge where input enters.
- Match existing codebase patterns; confirm a library is installed before using it
- Read secrets, keys, and tokens from the environment or a secret store; code and logs carry their names
- bun/bunx runs every package command and script

## Issues, specs, and any document a human reviews

Every issue, spec, PRD, or analysis you write or update has two readers: the agent that implements it and a human who must make sense of it in two minutes. Serve the human **first in the body**, above the agent-facing spec, in an "At a glance" section:

1. **Ask one clarifying question** before writing when the request leaves a real choice open (which fix, which scope, which reader). One question, then write.
2. **TL;DR** in three sentences: what is wrong, why, what changes.
3. **General case before this instance.** Describe the mechanism in general terms first so a reviewer can recognise the next occurrence, then the concrete case that exposed it.
4. **Evidence with real data.** Exact log lines, row values, server timestamps to the millisecond where event order is the point. Label estimates as estimates. Put failing cases beside working ones in a comparison table across the variables that might explain it, so correlation and its absence are both visible.
5. **More than one kind of visual.** Mermaid (renders in GitHub, Linear, most wikis) is the default for sequence, state, and flow. Pair it with at least one other form the mechanism calls for: a monospace timeline, an annotated code path, a before/after table, a can/cannot matrix. One idea per visual, with a caption.
6. **A picture version** via `/eli5` or a published artifact when the mechanism is subtle or the reviewer is someone other than the implementer. Link it at the foot: `[eli5 artifact: <name>](<url>)`.

**Done when** a reviewer who reads only "At a glance" can state the root cause, name the fix, and say what stays unchanged.

**On update**, a comment that changes the analysis (a correction, a measured number replacing an estimate, a new decision) carries its own evidence and visual, and the body is edited so it agrees with the comment.

## Writing Style

Be concise. Sacrifice grammar for concision. Write every reply in ASD-STE100 Simplified Technical English, the register the `wait-what` skill asks for, with the terms from `CONTEXT.md`: one idea per sentence, under 20 words, active voice, present tense, one name per thing, plain words, and a numbered list for a procedure. Say what you mean: when a literal phrase exists, use it. Facts, quotes, citations, and code stay as they are; style touches only the words around them.
