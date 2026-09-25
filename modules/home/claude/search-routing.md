# Code search routing: tool semantics, wrappers, traps

Reference behind the Search section of `~/.claude/CLAUDE.md`. That section names the tool per branch; this file carries what only some branches need. Numbers and failure modes measured 2026-09: `~/.claude/search-eval.md`. Dated output traces of each route: `~/.claude/references/search-routing-examples.md`.

## Wrappers on PATH

- `rw`: ripwire with node_modules excluded and legends stripped. `rw --verb=...` inside `<repo>`, `rw <repo> --verb=...` elsewhere.
- `rw --for="TERMS"` returns ranked signatures with caller (`in=`) and test (`tested=`) counts, then the doc sections that mention them. Outline the rank-1 file next.

## MCP or CLI

In the recorded September 2026 setup, codedb, fff, and zg run as MCP servers with typed parameters and no shell quoting. fff and codedb register with `alwaysLoad`; zg stays deferred behind ToolSearch. The recorded codedb startup was ~12 s, while its CLI was instant. Pass `project=<repo>` (codedb) or `root=<repo>` (zg).

Loaded schemas do not guarantee a ready server or current index. Use scoped `rg`, `fd`, or Read when MCP is unavailable, warming up, or stale; do not wait or retry solely to enforce routing. Read known paths directly. Read more only when returned context is insufficient or freshness is uncertain.

- codedb: `codedb_explain` for a symbol; `codedb_context` for a task, only with `semantic=local` (the default sends snippets to a remote reranker). Outline and read are CLI only.
- fff: `find_files` (fuzzy file names, frecency, git-dirty first; each extra word narrows), `grep` (one bare identifier, plain text, no regex), `multi_grep` (OR over literal patterns). `grep` marks the definition `[def]`. Read its header: `N/M matches`; `0 exact matches` means none in that indexed search scope, not absence from the whole checkout. The recorded setup caps replies at 50 hits; check the installed schema and result header rather than assuming this limit is universal. Use `rg -c` for matching-line counts, `rg -l` for matching-file lists, or untruncated `rg -n` for matching lines. fff honours `.ignore`. fff has no CLI on this machine: inside a subagent, load its MCP schema with ToolSearch or use rg.
- zg: `zvec_grep_search` for word-only orientation on one TypeScript repo, `fts: SYM` when you know a name. It returns vector neighbours even when nothing matched lexically, so a zg hit never proves presence; confirm with rg.

## rg flags

Scope paths and globs explicitly. Use `-F` for literals, `-e` for related patterns, `-C2` for context, and `-U` for multiline. `-c` counts matching lines, not individual occurrences.

For completeness checks, account for ignore rules, configuration, result limits, and read errors. `-uu` includes hidden and ignored files but does not guarantee coverage of binary files or symlink targets. Use `--no-config` only when a config-free audit is intended. Do not pipe completeness checks through `head`, suppress errors, or treat an execution error as no matches. State what was actually searched.

## Traps

- codedb's enclosing-function labels are wrong inside loops and lambdas; for the enclosing function or the flags a caller tests, `rw --callers=SYM`.
- `rw --uses=CONST` returns 0 for TypeScript constants; use `rg -w`.
- `rw --callers` misses calls inside anonymous callbacks such as test `it()` blocks.
- codedb skips node_modules and files over 2 MiB; rg covers them.
- `codedb word` is uncapped (27k lines for `Config`); a hook denies it without a pipe to head.
- The shell `grep` binary as a command is denied by a hook; `| grep` as a filter is fine.
- `rg -r` means `--replace`; never pass it.
- `~/devv` itself is 65k files of sibling checkouts; a hook denies rg there without a sub-path.
- A client-side limit is often mirrored by a differently named server constant joined only by a comment: after locating one, `rg -w` the identifier its comment names.
- `rw --edit-check=SYM` lists callers broken by a new arity. `rw --test-gate` exit 4 names tests to run and does not run them. `rw --quality-delta` exit 2 means a pre-existing symbol got materially worse.

## Structural patterns

ast-grep: `sg -p 'console.log($$$)' --lang ts`; rewrite with `sg --rewrite 'logger.debug($$$)' -p 'console.log($$$)'`.
